class_name PlaceholderFactory
extends RefCounted

## Fábrica de mallas y librerías para el GridMap.
## Combina modelos 3D con mallas procedurales y asegura que todos los elementos
## (suelos, muros, colisiones) posean formas de colisión físicas válidas en MeshLibrary.

const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func create_placeholder_library(biome: BiomeProfile, cell_size: float) -> MeshLibrary:
	var lib := MeshLibrary.new()
	if biome == null:
		biome = BiomeProfile.new()

	var floor_shape_size := Vector3(cell_size, 0.2, cell_size)

	# 0 = FLOOR: Modelo 3D personalizado si existe, o plano 2D con colisión física (Amarillo)
	var custom_floor_mesh := _extract_mesh_from_scene(biome.floor_scene, biome.floor_color)
	if custom_floor_mesh != null:
		lib.create_item(biome.floor_index)
		lib.set_item_mesh(biome.floor_index, custom_floor_mesh)
		lib.set_item_name(biome.floor_index, "Floor")
		_assign_collision_shape(lib, biome.floor_index, floor_shape_size)
	else:
		_add_plane_item(lib, biome.floor_index, Vector2(cell_size, cell_size), biome.floor_color, "Floor")

	# 1 = WALL: Modelo 3D o Pared Procedural Estilizada
	var custom_wall_mesh := _extract_mesh_from_scene(biome.wall_scene)
	if custom_wall_mesh != null:
		lib.create_item(biome.wall_index)
		lib.set_item_mesh(biome.wall_index, custom_wall_mesh)
		lib.set_item_name(biome.wall_index, "Wall")
		_assign_collision_shape(lib, biome.wall_index, Vector3(cell_size, cell_size * 2.0, cell_size))
	else:
		_add_procedural_wall_item(lib, biome.wall_index, _WallMeshConfigScript.PieceType.WALL, cell_size, "Wall")

	# 2 = WALL_CORNER: Esquina de muro 3D o Esquina en L Procedural Estilizada
	if biome.wall_corner_index >= 0:
		var custom_corner_mesh := _extract_mesh_from_scene(biome.wall_corner_scene)
		if custom_corner_mesh != null:
			lib.create_item(biome.wall_corner_index)
			lib.set_item_mesh(biome.wall_corner_index, custom_corner_mesh)
			lib.set_item_name(biome.wall_corner_index, "WallCorner")
			_assign_collision_shape(lib, biome.wall_corner_index, Vector3(cell_size, cell_size * 2.0, cell_size))
		else:
			_add_procedural_wall_item(lib, biome.wall_corner_index, _WallMeshConfigScript.PieceType.CORNER, cell_size, "WallCorner")

	# 3 = WALL_CAP: remate de muro procedural
	if biome.wall_cap_index >= 0:
		_add_procedural_wall_item(lib, biome.wall_cap_index, _WallMeshConfigScript.PieceType.WALL, cell_size, "WallCap")

	# 11 = WALL_ENDCAP: remate de muro personalizado o procedural
	if biome.wall_endcap_index >= 0:
		var custom_endcap_mesh := _extract_mesh_from_scene(biome.wall_endcap_scene)
		if custom_endcap_mesh != null:
			lib.create_item(biome.wall_endcap_index)
			lib.set_item_mesh(biome.wall_endcap_index, custom_endcap_mesh)
			lib.set_item_name(biome.wall_endcap_index, "WallEndcap")
			_assign_collision_shape(lib, biome.wall_endcap_index, Vector3(cell_size, cell_size * 2.0, cell_size))
		else:
			_add_procedural_wall_item(lib, biome.wall_endcap_index, _WallMeshConfigScript.PieceType.WALL, cell_size, "WallEndcap")

	# 10 = WALL_CORNER_SMALL: esquina pequeña de muro procedural
	if biome.wall_corner_small_index >= 0:
		var custom_corner_small_mesh := _extract_mesh_from_scene(biome.wall_corner_small_scene)
		if custom_corner_small_mesh != null:
			lib.create_item(biome.wall_corner_small_index)
			lib.set_item_mesh(biome.wall_corner_small_index, custom_corner_small_mesh)
			lib.set_item_name(biome.wall_corner_small_index, "WallCornerSmall")
			_assign_collision_shape(lib, biome.wall_corner_small_index, Vector3(cell_size, cell_size * 2.0, cell_size))
		else:
			_add_procedural_wall_item(lib, biome.wall_corner_small_index, _WallMeshConfigScript.PieceType.CORNER, cell_size, "WallCornerSmall")

	# 12 = DUNGEON_FLOOR: plano de piedra para base de pasillos (Verde)
	if biome.dungeon_floor_index >= 0:
		var corr_col: Color = biome.dungeon_floor_color if biome.dungeon_floor_color != Color.TRANSPARENT else biome.corridor_color
		var custom_dungeon_floor_mesh := _extract_mesh_from_scene(biome.dungeon_floor_scene, corr_col)
		if custom_dungeon_floor_mesh != null:
			lib.create_item(biome.dungeon_floor_index)
			lib.set_item_mesh(biome.dungeon_floor_index, custom_dungeon_floor_mesh)
			lib.set_item_name(biome.dungeon_floor_index, "DungeonFloor")
			_assign_collision_shape(lib, biome.dungeon_floor_index, floor_shape_size)
		else:
			_add_plane_item(lib, biome.dungeon_floor_index, Vector2(cell_size, cell_size), corr_col, "DungeonFloor")

	# 13 = WALL_TSPLIT: Muro en T
	if biome.wall_tsplit_index >= 0:
		var custom_tsplit_mesh := _extract_mesh_from_scene(biome.wall_tsplit_scene)
		if custom_tsplit_mesh != null:
			lib.create_item(biome.wall_tsplit_index)
			lib.set_item_mesh(biome.wall_tsplit_index, custom_tsplit_mesh)
			lib.set_item_name(biome.wall_tsplit_index, "WallTSplit")
			_assign_collision_shape(lib, biome.wall_tsplit_index, Vector3(cell_size, cell_size * 2.0, cell_size))
		else:
			_add_procedural_wall_item(lib, biome.wall_tsplit_index, _WallMeshConfigScript.PieceType.WALL, cell_size, "WallTSplit")

	# 14 = COLUMN: Columna / Pilar estructural 3D
	if biome.column_index >= 0:
		var custom_column_mesh := _extract_mesh_from_scene(biome.column_scene)
		if custom_column_mesh != null:
			lib.create_item(biome.column_index)
			lib.set_item_mesh(biome.column_index, custom_column_mesh)
			lib.set_item_name(biome.column_index, "Column")
			_assign_collision_shape(lib, biome.column_index, Vector3(cell_size, cell_size * 2.0, cell_size))
		else:
			_add_box_item(lib, biome.column_index, Vector3(cell_size * 0.5, cell_size * 2.0, cell_size * 0.5), biome.wall_color.darkened(0.2), "Column")

	# 4 = DOOR: Puerta estándar 3D
	if biome.door_index >= 0:
		var custom_door_mesh := _extract_mesh_from_scene(biome.door_scene)
		if custom_door_mesh != null:
			lib.create_item(biome.door_index)
			lib.set_item_mesh(biome.door_index, custom_door_mesh)
			lib.set_item_name(biome.door_index, "Door")
			_assign_collision_shape(lib, biome.door_index, Vector3(cell_size * 0.4, cell_size * 1.8, cell_size * 0.9))
		else:
			_add_box_item(lib, biome.door_index, Vector3(cell_size * 0.3, cell_size * 1.8, cell_size * 0.8), biome.door_color, "Door")

	# 5 = LOCKED_DOOR: Puerta cerrada con cerradura
	if biome.locked_door_index >= 0:
		var custom_locked_door_mesh := _extract_mesh_from_scene(biome.locked_door_scene)
		if custom_locked_door_mesh != null:
			lib.create_item(biome.locked_door_index)
			lib.set_item_mesh(biome.locked_door_index, custom_locked_door_mesh)
			lib.set_item_name(biome.locked_door_index, "LockedDoor")
			_assign_collision_shape(lib, biome.locked_door_index, Vector3(cell_size * 0.4, cell_size * 1.8, cell_size * 0.9))
		else:
			_add_box_item(lib, biome.locked_door_index, Vector3(cell_size * 0.3, cell_size * 1.8, cell_size * 0.8), biome.locked_door_color, "LockedDoor")

	# 6 = STAIRS_DOWN
	if biome.stairs_down_index >= 0:
		var custom_stairs_mesh := _extract_mesh_from_scene(biome.stairs_down_scene)
		if custom_stairs_mesh != null:
			lib.create_item(biome.stairs_down_index)
			lib.set_item_mesh(biome.stairs_down_index, custom_stairs_mesh)
			lib.set_item_name(biome.stairs_down_index, "StairsDown")
			_assign_collision_shape(lib, biome.stairs_down_index, floor_shape_size)
		else:
			_add_box_item(lib, biome.stairs_down_index, Vector3(cell_size, 0.4, cell_size), biome.stairs_color, "StairsDown")

	# 7 = STAIRS_UP
	if biome.stairs_up_index >= 0:
		var custom_stairs_up_mesh := _extract_mesh_from_scene(biome.stairs_up_scene)
		if custom_stairs_up_mesh != null:
			lib.create_item(biome.stairs_up_index)
			lib.set_item_mesh(biome.stairs_up_index, custom_stairs_up_mesh)
			lib.set_item_name(biome.stairs_up_index, "StairsUp")
			_assign_collision_shape(lib, biome.stairs_up_index, floor_shape_size)
		else:
			_add_box_item(lib, biome.stairs_up_index, Vector3(cell_size, 0.4, cell_size), biome.stairs_color, "StairsUp")

	# 8 = SPAWN_MARKER
	if biome.spawn_marker_index >= 0:
		_add_box_item(lib, biome.spawn_marker_index, Vector3(cell_size * 0.6, 0.05, cell_size * 0.6), biome.spawn_color, "SpawnMarker", true, Color.GREEN)

	# 9 = OBJECTIVE_MARKER
	if biome.objective_marker_index >= 0:
		_add_box_item(lib, biome.objective_marker_index, Vector3(cell_size * 0.6, 0.05, cell_size * 0.6), biome.objective_color, "ObjectiveMarker", true, Color.GOLD)

	# 15 = OBSTACLE
	if biome.obstacle_index >= 0:
		_add_box_item(lib, biome.obstacle_index, Vector3(cell_size * 0.7, cell_size * 0.7, cell_size * 0.7), biome.obstacle_color, "Obstacle")

	return lib

func _add_procedural_wall_item(
	lib: MeshLibrary,
	index: int,
	piece_type: _WallMeshConfigScript.PieceType,
	cell_size: float,
	item_name: String,
	cubes_high: int = 2
) -> void:
	if index < 0:
		return

	var builder := _WallMeshBuilderScript.new()
	var config := _WallMeshConfigScript.new()
	config.piece_type = piece_type
	config.centered_origin = true
	config.cube_size = cell_size
	config.cubes_high = cubes_high
	config.wall_length_cubes = 1

	var mesh: ArrayMesh = builder.build_wall_mesh(config)

	var trim_mat = _WallMaterialFactoryScript.create_trim_material(_WallMaterialFactoryScript.MaterialPreset.STYLIZED_SLATE)
	var panel_mat = _WallMaterialFactoryScript.create_panel_material(_WallMaterialFactoryScript.MaterialPreset.STYLIZED_SLATE)
	var brick_mat = _WallMaterialFactoryScript.create_brick_material(_WallMaterialFactoryScript.MaterialPreset.STYLIZED_SLATE)

	if mesh.get_surface_count() >= 3:
		mesh.surface_set_material(0, trim_mat)
		mesh.surface_set_material(1, panel_mat)
		mesh.surface_set_material(2, brick_mat)

	lib.create_item(index)
	lib.set_item_mesh(index, mesh)
	lib.set_item_name(index, item_name)
	_assign_collision_shape(lib, index, Vector3(cell_size, cell_size * float(cubes_high), cell_size))

func _assign_collision_shape(lib: MeshLibrary, index: int, size: Vector3, offset_y: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var xform := Transform3D(Basis(), Vector3(0.0, offset_y, 0.0))
	lib.set_item_shapes(index, [shape, xform])

func _add_plane_item(lib: MeshLibrary, index: int, size: Vector2, color: Color, item_name: String) -> void:
	if index < 0:
		return

	var mesh := PlaneMesh.new()
	mesh.size = size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat

	lib.create_item(index)
	lib.set_item_mesh(index, mesh)
	lib.set_item_name(index, item_name)
	_assign_collision_shape(lib, index, Vector3(size.x, 0.1, size.y), -0.05)

func _add_box_item(lib: MeshLibrary, index: int, size: Vector3, color: Color, item_name: String, emissive: bool = false, emission_color: Color = Color.BLACK) -> void:
	if index < 0:
		return

	var mesh := BoxMesh.new()
	mesh.size = size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.metallic = 0.1
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material = mat

	lib.create_item(index)
	lib.set_item_mesh(index, mesh)
	lib.set_item_name(index, item_name)
	_assign_collision_shape(lib, index, size)

func _extract_mesh_from_scene(scene: PackedScene, tint_color: Color = Color.WHITE) -> Mesh:
	if scene == null:
		return null
	var node: Node = scene.instantiate()
	if node == null:
		return null

	var mesh_instances: Array[MeshInstance3D] = []
	_find_all_mesh_instances(node, mesh_instances)

	if mesh_instances.is_empty():
		node.free()
		return null

	if mesh_instances.size() == 1:
		var single_mi: MeshInstance3D = mesh_instances[0]
		var final_mesh: Mesh = _duplicate_mesh_with_material(single_mi, tint_color)
		node.free()
		return final_mesh

	var combined_mesh := ArrayMesh.new()
	for mi in mesh_instances:
		if mi.mesh == null:
			continue
		var relative_xform: Transform3D = _get_relative_transform_to_root(mi, node)
		for s in range(mi.mesh.get_surface_count()):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null and mi.material_override != null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat != null:
				if tint_color != Color.WHITE and mat is StandardMaterial3D:
					var dup_mat: StandardMaterial3D = mat.duplicate()
					dup_mat.albedo_color = tint_color
					st.set_material(dup_mat)
				else:
					st.set_material(mat)
			elif tint_color != Color.WHITE:
				var new_mat := StandardMaterial3D.new()
				new_mat.albedo_color = tint_color
				st.set_material(new_mat)
			st.append_from(mi.mesh, s, relative_xform)
			st.commit(combined_mesh)

	node.free()
	return combined_mesh

func _get_relative_transform_to_root(current: Node3D, root_node: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = current
	while curr != null and curr != root_node:
		if curr is Node3D:
			xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

func _find_all_mesh_instances(current: Node, list: Array[MeshInstance3D]) -> void:
	if current is MeshInstance3D and current.mesh != null:
		list.append(current)
	for child in current.get_children():
		_find_all_mesh_instances(child, list)

func _duplicate_mesh_with_material(mesh_instance: MeshInstance3D, tint_color: Color = Color.WHITE) -> Mesh:
	var original: Mesh = mesh_instance.mesh
	if original == null:
		return null

	var mesh_copy: Mesh = original.duplicate()
	for s in range(mesh_instance.get_surface_override_material_count()):
		var mat := mesh_instance.get_surface_override_material(s)
		if mat != null:
			var dup_mat: Material = mat.duplicate()
			if tint_color != Color.WHITE and dup_mat is StandardMaterial3D:
				(dup_mat as StandardMaterial3D).albedo_color = tint_color
			mesh_copy.surface_set_material(s, dup_mat)

	if mesh_copy.get_surface_count() > 0:
		for s in range(mesh_copy.get_surface_count()):
			var surf_mat := mesh_copy.surface_get_material(s)
			if surf_mat == null:
				surf_mat = original.surface_get_material(s)
			if surf_mat != null:
				var dup_mat: Material = surf_mat.duplicate()
				if tint_color != Color.WHITE and dup_mat is StandardMaterial3D:
					(dup_mat as StandardMaterial3D).albedo_color = tint_color
				mesh_copy.surface_set_material(s, dup_mat)
			elif tint_color != Color.WHITE:
				var new_mat := StandardMaterial3D.new()
				new_mat.albedo_color = tint_color
				mesh_copy.surface_set_material(s, new_mat)

	if mesh_instance.material_override != null and mesh_copy.get_surface_count() > 0:
		var override_mat: Material = mesh_instance.material_override.duplicate()
		if tint_color != Color.WHITE and override_mat is StandardMaterial3D:
			(override_mat as StandardMaterial3D).albedo_color = tint_color
		mesh_copy.surface_set_material(0, override_mat)

	return mesh_copy
