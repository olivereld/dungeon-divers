class_name DungeonStairSpawner
extends RefCounted

## Spawner y materializador físico de escaleras en Presentation (Fase 10 - Verticalidad).
## Instancia escenas personalizadas (biome.stairs_up_scene / stairs_down_scene) o genera
## tramos de escaleras de piedra procedurales con colisión física y materiales estilizados.

const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

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

	# Preparar mallas procedurales de escalera ascendente y descendente
	var stair_up_mesh: ArrayMesh = null
	var stair_down_mesh: ArrayMesh = null

	if biome == null or (biome.stairs_up_scene == null and biome.stairs_down_scene == null):
		stair_up_mesh = _build_procedural_stair_mesh(tile_size, 1.8, false)
		stair_down_mesh = _build_procedural_stair_mesh(tile_size, 1.8, true)

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
			var mi := MeshInstance3D.new()
			mi.mesh = stair_down_mesh if st.is_downward else stair_up_mesh
			mi.create_trimesh_collision()
			stair_node = mi

		if stair_node != null:
			stair_node.name = "Stair_%s" % st.stair_id
			var pos_3d: Vector3 = _GridToWorldScript.get_cell_center_world_3d(
				st.cell, st.floor_number, tile_size, floor_height, 0.0
			)
			stair_node.position = pos_3d
			stair_node.rotation = Vector3(0.0, st.orientation, 0.0)

			stairs_container.add_child(stair_node)
			result["spawned_stairs"].append(stair_node)

	return result

## Construye una malla procedural estilizada de tramo de escalera de piedra con pretiles.
static func _build_procedural_stair_mesh(
	tile_size: float = 2.0,
	stair_rise: float = 1.8,
	is_downward: bool = false
) -> ArrayMesh:
	var st_steps := SurfaceTool.new()
	var st_railings := SurfaceTool.new()
	st_steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_railings.begin(Mesh.PRIMITIVE_TRIANGLES)

	var num_steps: int = 8
	var step_depth: float = (tile_size * 0.85) / float(num_steps)
	var step_height: float = stair_rise / float(num_steps)
	var step_width: float = tile_size * 0.70
	var half_w: float = step_width * 0.5
	var start_z: float = -(tile_size * 0.85) * 0.5

	# 1. Generar los peldaños (Steps)
	for i in range(num_steps):
		var y0: float = float(i) * step_height
		var y1: float = float(i + 1) * step_height
		var z0: float = start_z + (float(i) * step_depth)
		var z1: float = start_z + (float(i + 1) * step_depth)

		if is_downward:
			y0 = -y0
			y1 = -y1

		# Huella horizontal del peldaño (Tread)
		_add_quad(st_steps,
			Vector3(-half_w, y1, z0),
			Vector3(half_w, y1, z0),
			Vector3(half_w, y1, z1),
			Vector3(-half_w, y1, z1)
		)

		# Contrahuella vertical del peldaño (Riser)
		_add_quad(st_steps,
			Vector3(-half_w, y0, z0),
			Vector3(half_w, y0, z0),
			Vector3(half_w, y1, z0),
			Vector3(-half_w, y1, z0)
		)

	# 2. Generar Pretiles / Zancas Laterales (Side Stringers)
	var railing_th: float = 0.12
	var railing_h: float = 0.35
	var rail_w_left_min: float = -half_w - railing_th
	var rail_w_left_max: float = -half_w
	var rail_w_right_min: float = half_w
	var rail_w_right_max: float = half_w + railing_th

	_build_side_stringer(st_railings, rail_w_left_min, rail_w_left_max, start_z, start_z + (float(num_steps) * step_depth), stair_rise, railing_h, is_downward)
	_build_side_stringer(st_railings, rail_w_right_min, rail_w_right_max, start_z, start_z + (float(num_steps) * step_depth), stair_rise, railing_h, is_downward)

	var mesh := ArrayMesh.new()
	var steps_arr := st_steps.commit_to_arrays()
	if steps_arr.size() > 0 and steps_arr[Mesh.ARRAY_VERTEX] != null and steps_arr[Mesh.ARRAY_VERTEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, steps_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "StairSteps")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_panel_material())

	var rails_arr := st_railings.commit_to_arrays()
	if rails_arr.size() > 0 and rails_arr[Mesh.ARRAY_VERTEX] != null and rails_arr[Mesh.ARRAY_VERTEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rails_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "StairRailings")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_trim_material())

	return mesh

static func _build_side_stringer(
	st: SurfaceTool,
	min_x: float, max_x: float,
	min_z: float, max_z: float,
	total_rise: float,
	rail_height: float,
	is_downward: bool
) -> void:
	var top_y0: float = rail_height
	var top_y1: float = (total_rise if not is_downward else -total_rise) + rail_height
	var bot_y0: float = 0.0
	var bot_y1: float = total_rise if not is_downward else -total_rise

	# Cara Superior
	_add_quad(st,
		Vector3(min_x, top_y0, min_z),
		Vector3(max_x, top_y0, min_z),
		Vector3(max_x, top_y1, max_z),
		Vector3(min_x, top_y1, max_z)
	)
	# Cara Exterior Izquierda / Derecha
	_add_quad(st,
		Vector3(min_x, bot_y0, min_z),
		Vector3(min_x, bot_y1, max_z),
		Vector3(min_x, top_y1, max_z),
		Vector3(min_x, top_y0, min_z)
	)
	_add_quad(st,
		Vector3(max_x, bot_y1, max_z),
		Vector3(max_x, bot_y0, min_z),
		Vector3(max_x, top_y0, min_z),
		Vector3(max_x, top_y1, max_z)
	)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p3)
