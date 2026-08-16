class_name PlaceholderFactory
extends RefCounted

## Fábrica de mallas y librerías para el GridMap.
## Permite combinar modelos 3D reales (.gltf / .glb / PackedScene) con cajas de color para slots sin assets.

func create_placeholder_library(biome: BiomeProfile, cell_size: float) -> MeshLibrary:
	var lib := MeshLibrary.new()
	if biome == null:
		biome = BiomeProfile.new()

	# 0 = FLOOR: Modelo 3D personalizado si existe, o losa plana
	var custom_floor_mesh := _extract_mesh_from_scene(biome.floor_scene)
	if custom_floor_mesh != null:
		lib.create_item(biome.floor_index)
		lib.set_item_mesh(biome.floor_index, custom_floor_mesh)
		lib.set_item_name(biome.floor_index, "Floor")
	else:
		_add_box_item(lib, biome.floor_index, Vector3(cell_size, 0.1, cell_size), biome.floor_color, "Floor")

	# 1 = WALL: Modelo 3D o cubo sólido
	var custom_wall_mesh := _extract_mesh_from_scene(biome.wall_scene)
	if custom_wall_mesh != null:
		lib.create_item(biome.wall_index)
		lib.set_item_mesh(biome.wall_index, custom_wall_mesh)
		lib.set_item_name(biome.wall_index, "Wall")
	else:
		_add_box_item(lib, biome.wall_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "Wall")

	# 2 = WALL_CORNER: esquina de muro personalizada o cubo
	if biome.wall_corner_index >= 0:
		var custom_corner_mesh := _extract_mesh_from_scene(biome.wall_corner_scene)
		if custom_corner_mesh != null:
			lib.create_item(biome.wall_corner_index)
			lib.set_item_mesh(biome.wall_corner_index, custom_corner_mesh)
			lib.set_item_name(biome.wall_corner_index, "WallCorner")
		else:
			_add_box_item(lib, biome.wall_corner_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "WallCorner")

	# 3 = WALL_CAP: remate de muro
	if biome.wall_cap_index >= 0:
		_add_box_item(lib, biome.wall_cap_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "WallCap")

	# 11 = WALL_ENDCAP: remate de muro personalizado
	if biome.wall_endcap_index >= 0:
		var custom_endcap_mesh := _extract_mesh_from_scene(biome.wall_endcap_scene)
		if custom_endcap_mesh != null:
			lib.create_item(biome.wall_endcap_index)
			lib.set_item_mesh(biome.wall_endcap_index, custom_endcap_mesh)
			lib.set_item_name(biome.wall_endcap_index, "WallEndcap")
		else:
			_add_box_item(lib, biome.wall_endcap_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "WallEndcap")

	# 10 = WALL_CORNER_SMALL: esquina pequeña de muro
	if biome.wall_corner_small_index >= 0:
		var custom_corner_small_mesh := _extract_mesh_from_scene(biome.wall_corner_small_scene)
		if custom_corner_small_mesh != null:
			lib.create_item(biome.wall_corner_small_index)
			lib.set_item_mesh(biome.wall_corner_small_index, custom_corner_small_mesh)
			lib.set_item_name(biome.wall_corner_small_index, "WallCornerSmall")
		else:
			_add_box_item(lib, biome.wall_corner_small_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "WallCornerSmall")

	# 12 = DUNGEON_FLOOR: losa de piedra para base de muros y pasillos
	if biome.dungeon_floor_index >= 0:
		var custom_dungeon_floor_mesh := _extract_mesh_from_scene(biome.dungeon_floor_scene)
		if custom_dungeon_floor_mesh != null:
			lib.create_item(biome.dungeon_floor_index)
			lib.set_item_mesh(biome.dungeon_floor_index, custom_dungeon_floor_mesh)
			lib.set_item_name(biome.dungeon_floor_index, "DungeonFloor")
		else:
			_add_box_item(lib, biome.dungeon_floor_index, Vector3(cell_size, 0.1, cell_size), biome.dungeon_floor_color, "DungeonFloor")

	# 13 = WALL_TSPLIT: Muro en T para intersecciones y divisiones
	if biome.wall_tsplit_index >= 0:
		var custom_tsplit_mesh := _extract_mesh_from_scene(biome.wall_tsplit_scene)
		if custom_tsplit_mesh != null:
			lib.create_item(biome.wall_tsplit_index)
			lib.set_item_mesh(biome.wall_tsplit_index, custom_tsplit_mesh)
			lib.set_item_name(biome.wall_tsplit_index, "WallTSplit")
		else:
			_add_box_item(lib, biome.wall_tsplit_index, Vector3(cell_size, cell_size, cell_size), biome.wall_color, "WallTSplit")

	# 14 = COLUMN: Columna / Pilar estructural 3D
	if biome.column_index >= 0:
		var custom_column_mesh := _extract_mesh_from_scene(biome.column_scene)
		if custom_column_mesh != null:
			lib.create_item(biome.column_index)
			lib.set_item_mesh(biome.column_index, custom_column_mesh)
			lib.set_item_name(biome.column_index, "Column")
		else:
			_add_box_item(lib, biome.column_index, Vector3(cell_size * 0.4, cell_size * 1.2, cell_size * 0.4), biome.column_color, "Column")

	# 4 = DOOR: Modelo 3D o puerta marrón
	var custom_door_mesh := _extract_mesh_from_scene(biome.door_scene)
	if custom_door_mesh != null:
		lib.create_item(biome.door_index)
		lib.set_item_mesh(biome.door_index, custom_door_mesh)
		lib.set_item_name(biome.door_index, "Door")
	else:
		_add_box_item(lib, biome.door_index, Vector3(cell_size * 0.9, cell_size * 0.9, cell_size * 0.25), biome.door_color, "Door")

	# 5 = LOCKED_DOOR: Modelo 3D o puerta roja
	var custom_locked_door_mesh := _extract_mesh_from_scene(biome.locked_door_scene)
	if custom_locked_door_mesh != null:
		lib.create_item(biome.locked_door_index)
		lib.set_item_mesh(biome.locked_door_index, custom_locked_door_mesh)
		lib.set_item_name(biome.locked_door_index, "LockedDoor")
	else:
		_add_box_item(lib, biome.locked_door_index, Vector3(cell_size * 0.9, cell_size * 0.9, cell_size * 0.3), biome.locked_door_color, "LockedDoor", true, biome.locked_door_color * 0.5)

	# 6 = STAIRS_DOWN: Modelo 3D o escalera azulada
	var custom_stairs_down_mesh := _extract_mesh_from_scene(biome.stairs_down_scene)
	if custom_stairs_down_mesh != null:
		lib.create_item(biome.stairs_down_index)
		lib.set_item_mesh(biome.stairs_down_index, custom_stairs_down_mesh)
		lib.set_item_name(biome.stairs_down_index, "StairsDown")
	else:
		_add_box_item(lib, biome.stairs_down_index, Vector3(cell_size * 0.9, 0.2, cell_size * 0.9), biome.stairs_color, "StairsDown", true, biome.stairs_color * 0.4)

	# 7 = STAIRS_UP: Modelo 3D o escalera ascendente
	var custom_stairs_up_mesh := _extract_mesh_from_scene(biome.stairs_up_scene)
	if custom_stairs_up_mesh != null:
		lib.create_item(biome.stairs_up_index)
		lib.set_item_mesh(biome.stairs_up_index, custom_stairs_up_mesh)
		lib.set_item_name(biome.stairs_up_index, "StairsUp")
	else:
		_add_box_item(lib, biome.stairs_up_index, Vector3(cell_size * 0.9, 0.2, cell_size * 0.9), biome.stairs_color, "StairsUp")

	# 8 = SPAWN Marker: Pilar Verde brillante visible en 3D
	if biome.spawn_marker_index >= 0:
		_add_box_item(lib, biome.spawn_marker_index, Vector3(cell_size * 0.5, cell_size * 1.2, cell_size * 0.5), biome.spawn_color, "SpawnMarker", true, biome.spawn_color * 0.8)

	# 9 = OBJECTIVE Marker: Tótem Dorado brillante visible en 3D
	if biome.objective_marker_index >= 0:
		_add_box_item(lib, biome.objective_marker_index, Vector3(cell_size * 0.6, cell_size * 1.5, cell_size * 0.6), biome.objective_color, "ObjectiveMarker", true, biome.objective_color * 0.8)

	# CORRIDOR: losa de color alternativo si está configurado
	if biome.corridor_index >= 0:
		_add_box_item(lib, biome.corridor_index, Vector3(cell_size, 0.1, cell_size), biome.corridor_color, "Corridor")

	return lib

func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
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

	if mesh_instances.size() == 1 and mesh_instances[0] == node:
		var single_mesh: Mesh = _duplicate_mesh_with_material(mesh_instances[0])
		node.free()
		return single_mesh

	# Combinar múltiples MeshInstance3Ds respetando sus transforms locales
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
				st.set_material(mat)
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

func _duplicate_mesh_with_material(mesh_instance: MeshInstance3D) -> Mesh:
	var original: Mesh = mesh_instance.mesh
	if original == null:
		return null

	var mesh_copy: Mesh = original.duplicate()
	for s in range(mesh_instance.get_surface_override_material_count()):
		var mat := mesh_instance.get_surface_override_material(s)
		if mat != null:
			mesh_copy.surface_set_material(s, mat)

	if mesh_instance.material_override != null and mesh_copy.get_surface_count() > 0:
		mesh_copy.surface_set_material(0, mesh_instance.material_override)

	return mesh_copy

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
