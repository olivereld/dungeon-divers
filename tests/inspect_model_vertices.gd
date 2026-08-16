extends SceneTree

func _init() -> void:
	print("--- Inspecting vertex positions of wall and wall_corner ---")
	var wall_res = load("res://models/dungeon/wall/wall.gltf")
	var wall_node: Node3D = wall_res.instantiate()
	var wall_mesh: Mesh = wall_node.get_node("wall").mesh
	var wall_data := MeshDataTool.new()
	var wall_arr_mesh := ArrayMesh.new()
	wall_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_mesh.surface_get_arrays(0))
	wall_data.create_from_surface(wall_arr_mesh, 0)
	print("Wall vertex count: ", wall_data.get_vertex_count())
	var wall_min := Vector3(999,999,999)
	var wall_max := Vector3(-999,-999,-999)
	for i in range(wall_data.get_vertex_count()):
		var v := wall_data.get_vertex(i)
		wall_min.x = minf(wall_min.x, v.x)
		wall_min.y = minf(wall_min.y, v.y)
		wall_min.z = minf(wall_min.z, v.z)
		wall_max.x = maxf(wall_max.x, v.x)
		wall_max.y = maxf(wall_max.y, v.y)
		wall_max.z = maxf(wall_max.z, v.z)
	print("Wall bounds: min=", wall_min, " max=", wall_max)

	var corner_res = load("res://models/dungeon/wall_corner/wall_corner.gltf")
	var corner_node: Node3D = corner_res.instantiate()
	var corner_mesh: Mesh = corner_node.get_node("wall_corner").mesh
	var corner_data := MeshDataTool.new()
	var corner_arr_mesh := ArrayMesh.new()
	corner_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, corner_mesh.surface_get_arrays(0))
	corner_data.create_from_surface(corner_arr_mesh, 0)
	print("Corner vertex count: ", corner_data.get_vertex_count())
	var corner_min := Vector3(999,999,999)
	var corner_max := Vector3(-999,-999,-999)
	for i in range(corner_data.get_vertex_count()):
		var v := corner_data.get_vertex(i)
		corner_min.x = minf(corner_min.x, v.x)
		corner_min.y = minf(corner_min.y, v.y)
		corner_min.z = minf(corner_min.z, v.z)
		corner_max.x = maxf(corner_max.x, v.x)
		corner_max.y = maxf(corner_max.y, v.y)
		corner_max.z = maxf(corner_max.z, v.z)
	print("Corner bounds: min=", corner_min, " max=", corner_max)

	quit(0)
