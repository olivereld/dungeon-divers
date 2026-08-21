class_name DungeonStairSpawner
extends RefCounted

## Spawner y materializador físico de escaleras en Presentation (Fase 10 - Verticalidad).
## Instancia escenas personalizadas (biome.stairs_up_scene / stairs_down_scene) o materializa
## mallas desde StairGeometryBuilder con colisión física, trigger de interacción (Area3D) y metadatos de transición.

const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
const _StairGeometryBuilderScript = preload("res://src/geometry_generator/geometry/stair_geometry_builder.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")

## Spawnea todas las escaleras de la lista en el StagingRoot.
func spawn_stairs(
	stairs: Array,
	staging_root: Node3D,
	biome: BiomeProfile,
	tile_size: float = 2.0,
	floor_height: float = 6.0,
	seed_val: int = 1337
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

	# Altura estándar del prop visual de escalera dentro de la instancia del piso (1.8m)
	var visual_stair_rise: float = 1.8

	# Preparar mallas procedurales de escalera ascendente y descendente desde StairGeometryBuilder
	var stair_builder = _StairGeometryBuilderScript.new()
	var stair_up_gm = null
	var stair_down_gm = null

	if biome == null or (biome.stairs_up_scene == null and biome.stairs_down_scene == null):
		var cfg_up = _StairGeometryConfigScript.new()
		cfg_up.tile_size = tile_size
		cfg_up.stair_rise = visual_stair_rise
		cfg_up.is_downward = false
		cfg_up.seed = seed_val
		stair_up_gm = stair_builder.build_stair_mesh(cfg_up)

		var cfg_down = _StairGeometryConfigScript.new()
		cfg_down.tile_size = tile_size
		cfg_down.stair_rise = visual_stair_rise
		cfg_down.is_downward = true
		cfg_down.seed = seed_val
		stair_down_gm = stair_builder.build_stair_mesh(cfg_down)

	for st in stairs:
		if st == null:
			continue

		var stair_node: Node3D = null

		if biome != null:
			if not st.is_downward and biome.stairs_up_scene != null:
				stair_node = biome.stairs_up_scene.instantiate() as Node3D
			elif st.is_downward and biome.stairs_down_scene != null:
				stair_node = biome.stairs_down_scene.instantiate() as Node3D

		if stair_node == null:
			var target_gm = stair_down_gm if st.is_downward else stair_up_gm
			if target_gm != null and target_gm.mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = target_gm.mesh
				# Aplicar materiales PBR configurados en GeneratedMesh
				for slot in target_gm.material_slots.keys():
					mi.set_surface_override_material(slot, target_gm.material_slots[slot])
				mi.create_trimesh_collision()
				stair_node = mi

		if stair_node != null:
			stair_node.name = "Stair_%s" % st.stair_id
			var pos_3d: Vector3 = _GridToWorldScript.get_cell_center_world_3d(
				st.cell, st.floor_number, tile_size, floor_height, 0.0
			)
			stair_node.position = pos_3d
			stair_node.rotation = Vector3(0.0, st.orientation, 0.0)

			# 1. Inyectar metadatos para el FloorTransitionSystem / Interacción
			stair_node.set_meta("stair_id", st.stair_id)
			stair_node.set_meta("floor_number", st.floor_number)
			stair_node.set_meta("target_floor", st.target_floor)
			stair_node.set_meta("connection_id", st.connection_id)
			stair_node.set_meta("is_downward", st.is_downward)
			stair_node.set_meta("cell", st.cell)
			stair_node.set_meta("orientation", st.orientation)

			# 2. Agregar trigger de interacción (Area3D) para detección de proximidad del jugador
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

