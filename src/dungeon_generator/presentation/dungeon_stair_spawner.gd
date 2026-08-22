class_name DungeonStairSpawner
extends RefCounted

## Spawner y materializador físico de escaleras en Presentation (Fase 10 - Verticalidad).
## Instancia escenas personalizadas (biome.stairs_up_scene / stairs_down_scene) o materializa
## mallas desde StairGeometryBuilder aplicando las especificaciones resueltas por StairsPresentationResolver.

const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
const _StairGeometryBuilderScript = preload("res://src/geometry_generator/geometry/stair_geometry_builder.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")
const _StairsPresentationContextScript = preload("res://src/presentation/architecture/stairs_presentation_context.gd")
const _StairsPresentationResolverScript = preload("res://src/presentation/architecture/stairs_presentation_resolver.gd")

var _resolver := _StairsPresentationResolverScript.new()

## Spawnea todas las escaleras de la lista en el StagingRoot.
func spawn_stairs(
	stairs: Array,
	staging_root: Node3D,
	biome: BiomeProfile,
	tile_size: float = 2.0,
	floor_height: float = 6.0,
	seed_val: int = 1337,
	partition = null,
	stairs_contexts: Array = []
) -> Dictionary:
	var result := {
		"spawned_stairs": [],
		"diagnostics": []
	}

	if stairs.is_empty() or staging_root == null:
		return result

	var stairs_container := Node3D.new()
	stairs_container.name = "Stairs"
	staging_root.add_child(stairs_container)

	# 1. Indexar contextos de escalera por stair_id y connection_id en O(contexts)
	var context_by_id: Dictionary = {}
	for ctx in stairs_contexts:
		if ctx != null:
			if "stair_id" in ctx and not ctx.stair_id.is_empty():
				context_by_id[ctx.stair_id] = ctx
			if "connection_id" in ctx and not ctx.connection_id.is_empty():
				context_by_id[ctx.connection_id] = ctx

	# Altura estándar del prop visual de escalera dentro de la instancia del piso (1.8m)
	var visual_stair_rise: float = 1.8
	var stair_builder := _StairGeometryBuilderScript.new()

	for st in stairs:
		if st == null:
			continue

		# 2. Obtener contexto y resolver especificaciones arquitectónicas
		var s_ctx: _StairsPresentationContextScript = context_by_id.get(st.stair_id, null)
		if s_ctx == null:
			s_ctx = context_by_id.get(st.connection_id, null)
		if s_ctx == null and partition != null:
			s_ctx = _StairsPresentationContextScript.new(
				st.stair_id, st.connection_id, st.floor_number, st.target_floor,
				st.cell, partition.get_room_id_at(st.cell), null, null, st.is_downward, st.orientation
			)

		var specs: Dictionary = _resolver.resolve_stairs_specs(s_ctx, tile_size, floor_height)

		var stair_node: Node3D = null

		if biome != null:
			if not st.is_downward and biome.stairs_up_scene != null:
				stair_node = biome.stairs_up_scene.instantiate() as Node3D
			elif st.is_downward and biome.stairs_down_scene != null:
				stair_node = biome.stairs_down_scene.instantiate() as Node3D

		if stair_node == null:
			var cfg := _StairGeometryConfigScript.new()
			cfg.tile_size = tile_size
			cfg.stair_rise = specs.get("visual_rise", visual_stair_rise)
			cfg.is_downward = st.is_downward
			cfg.seed = seed_val

			var gm = stair_builder.build_stair_mesh(cfg)
			if gm != null and gm.mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = gm.mesh
				for slot in gm.material_slots.keys():
					mi.set_surface_override_material(slot, gm.material_slots[slot])
				mi.create_trimesh_collision()
				stair_node = mi

		if stair_node != null:
			stair_node.name = "Stair_%s" % st.stair_id
			var pos_3d: Vector3 = _GridToWorldScript.get_cell_center_world(
				st.cell, tile_size, 0.0
			)
			stair_node.position = pos_3d
			stair_node.rotation = Vector3(0.0, st.orientation, 0.0)

			# Inyectar metadatos para FloorTransitionSystem / Interacción
			stair_node.set_meta("stair_id", st.stair_id)
			stair_node.set_meta("floor_number", st.floor_number)
			stair_node.set_meta("target_floor", st.target_floor)
			stair_node.set_meta("connection_id", st.connection_id)
			stair_node.set_meta("is_downward", st.is_downward)
			stair_node.set_meta("cell", st.cell)
			stair_node.set_meta("orientation", st.orientation)
			stair_node.set_meta("stairs_context", s_ctx)
			stair_node.set_meta("resolved_style", specs.get("stairs_style", 0))

			# Trigger de interacción (Area3D)
			var interact_area := Area3D.new()
			interact_area.name = "InteractionArea"
			var col_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(tile_size * 0.9, visual_stair_rise + 0.4, tile_size * 0.9)
			col_shape.shape = box
			col_shape.position = Vector3(0.0, (visual_stair_rise + 0.4) * 0.5, 0.0)
			interact_area.add_child(col_shape)
			stair_node.add_child(interact_area)

			stairs_container.add_child(stair_node)
			result["spawned_stairs"].append(stair_node)

	return result
