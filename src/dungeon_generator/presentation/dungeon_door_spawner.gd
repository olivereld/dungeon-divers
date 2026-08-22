class_name DungeonDoorSpawner
extends RefCounted

## Spawner y materializador físico de puertas en Presentation (Fase 9).
## Instancia escenas personalizadas (biome.door_scene) o genera portales completos
## que combinan el marco/arco procedural y la hoja de puerta resuelta por DoorPresentationResolver.

const _DungeonDoorManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")
const _DungeonDoorEntityScript = preload("res://src/dungeon_generator/presentation/entities/dungeon_door_entity.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _DoorPhysicalValidatorScript = preload("res://src/dungeon_generator/core/validation/door_physical_validator.gd")
const _DoorPresentationContextScript = preload("res://src/presentation/architecture/door_presentation_context.gd")
const _DoorPresentationResolverScript = preload("res://src/presentation/architecture/door_presentation_resolver.gd")

var _resolver := _DoorPresentationResolverScript.new()

## Spawnea todas las puertas a partir de los manifiestos y contextos en el StagingRoot.
func spawn_doors(
	door_manifests: Array[DungeonDoorManifest],
	staging_root: Node3D,
	biome: BiomeProfile,
	tile_size: float = 2.0,
	wall_height: int = 2,
	seed_val: int = 1337,
	grid: CellGrid = null,
	partition = null,
	door_contexts: Array = []
) -> Dictionary:
	var result := {
		"spawned_doors": [],
		"diagnostics": []
	}

	if door_manifests.is_empty() or staging_root == null:
		return result

	var doors_container := Node3D.new()
	doors_container.name = "Doors"
	staging_root.add_child(doors_container)

	# 1. Indexar contextos de puerta por door_id y connection_id en O(contexts)
	var context_by_id: Dictionary = {}
	for ctx in door_contexts:
		if ctx != null:
			if "door_id" in ctx and not ctx.door_id.is_empty():
				context_by_id[ctx.door_id] = ctx
			if "connection_id" in ctx and ctx.connection_id >= 0:
				context_by_id[str(ctx.connection_id)] = ctx

	var mesh_facade := _DungeonMeshGeneratorScript.new()

	for manifest in door_manifests:
		if manifest == null:
			continue

		# Validar jambas físicas sólidas
		if grid != null and not _DoorPhysicalValidatorScript.validate_door_jambs(grid, manifest.cell, manifest.side):
			continue

		# 2. Obtener contexto y resolver especificaciones arquitectónicas
		var d_ctx: _DoorPresentationContextScript = context_by_id.get(manifest.door_id, null)
		if d_ctx == null:
			d_ctx = context_by_id.get(manifest.connection_id, null)
		if d_ctx == null and partition != null:
			# Fallback constructivo desde partición
			d_ctx = _DoorPresentationContextScript.new(
				int(manifest.connection_id) if manifest.connection_id.is_valid_int() else -1,
				manifest.door_id,
				partition.get_room_id_at(manifest.cell),
				partition.get_room_id_at(manifest.adjacent_cell),
				null, null, manifest.cell, manifest.adjacent_cell
			)

		var specs: Dictionary = _resolver.resolve_door_specs(d_ctx, tile_size, wall_height)

		var portal_root: Node3D = null

		if biome != null and biome.door_scene != null:
			portal_root = biome.door_scene.instantiate() as Node3D
		else:
			var is_open: bool = (manifest.door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE)

			# 1. Malla del Marco / Arco
			var arch_cfg := _ArchGeometryConfigScript.new()
			arch_cfg.width = specs.get("frame_width", tile_size)
			arch_cfg.height = specs.get("frame_height", float(wall_height) * tile_size)
			arch_cfg.opening_width = specs.get("opening_width", tile_size * 0.55)
			arch_cfg.opening_height = specs.get("opening_height", float(wall_height) * tile_size * 0.70)
			arch_cfg.seed = seed_val
			arch_cfg.centered_origin = true

			var arch_gm = mesh_facade.generate_arch(arch_cfg)
			var arch_mesh: Mesh = arch_gm.mesh if arch_gm != null else null

			# 2. Malla de la Hoja de Puerta
			var door_w: float = arch_cfg.opening_width - 0.02
			var door_h: float = arch_cfg.opening_height - 0.01

			var door_cfg := _DoorGeometryConfigScript.new()
			door_cfg.door_width = door_w
			door_cfg.door_height = door_h
			door_cfg.seed = seed_val
			door_cfg.centered_origin = true
			var door_th: float = door_cfg.door_thickness

			var leaf_gm = mesh_facade.generate_door_leaf(door_cfg)
			var door_leaf_mesh: Mesh = leaf_gm.mesh if leaf_gm != null else null

			if arch_mesh != null:
				portal_root = Node3D.new()
				portal_root.name = "DoorPortal_%s" % manifest.door_id

				# Arco de piedra exterior con colisión
				var arch_inst := MeshInstance3D.new()
				arch_inst.name = "StoneArch"
				arch_inst.mesh = arch_mesh
				_WallMaterialFactoryScript.apply_materials_to_mesh_instance(arch_inst)
				arch_inst.create_trimesh_collision()
				portal_root.add_child(arch_inst)

				# Hoja de puerta interactiva y destructible
				if door_leaf_mesh != null and not is_open:
					var door_entity := _DungeonDoorEntityScript.new()
					door_entity.name = "DoorEntity"
					door_entity.setup_procedural_door(
						door_leaf_mesh,
						door_w,
						door_h,
						door_th
					)
					portal_root.add_child(door_entity)

		if portal_root != null:
			var pos_3d: Vector3 = calculate_door_world_position(manifest.cell, manifest.side, tile_size)
			var rot_y: float = calculate_door_orientation(manifest.side)

			portal_root.position = pos_3d
			portal_root.rotation = Vector3(0.0, rot_y, 0.0)
			portal_root.set_meta("door_context", d_ctx)
			portal_root.set_meta("resolved_style", specs.get("door_style", 0))

			doors_container.add_child(portal_root)
			result["spawned_doors"].append(portal_root)

	return result

## Calcula la posición 3D exacta del portal centrado en la celda de puerta.
static func calculate_door_world_position(cell: Vector2i, side: int, tile_size: float = 2.0) -> Vector3:
	var half: float = tile_size * 0.5
	var center_x: float = (float(cell.x) * tile_size) + half
	var center_z: float = (float(cell.y) * tile_size) + half
	return Vector3(center_x, 0.0, center_z)

## Calcula la rotación en el eje Y según el lado cardinal.
static func calculate_door_orientation(side: int) -> float:
	match side:
		_RoomEntranceScript.NORTH:
			return 0.0
		_RoomEntranceScript.SOUTH:
			return PI
		_RoomEntranceScript.WEST:
			return PI * 0.5
		_RoomEntranceScript.EAST:
			return -PI * 0.5
	return 0.0
