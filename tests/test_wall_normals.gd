extends SceneTree

func _init() -> void:
	print("--- Checking wall face normal ---")
	var wall_res = load("res://models/dungeon/wall/wall.gltf")
	var wall_node: Node3D = wall_res.instantiate()
	var wall_mesh: Mesh = wall_node.get_node("wall").mesh
	var data := MeshDataTool.new()
	var arr := ArrayMesh.new()
	arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_mesh.surface_get_arrays(0))
	data.create_from_surface(arr, 0)

	var normal_counts := {
		"+Z (South)": 0,
		"-Z (North)": 0,
		"+X (East)": 0,
		"-X (West)": 0,
		"+Y (Top)": 0,
		"-Y (Bottom)": 0
	}
	for i in range(data.get_face_count()):
		var n := data.get_face_normal(i)
		if n.dot(Vector3(0, 0, 1)) > 0.8:
			normal_counts["+Z (South)"] += 1
		elif n.dot(Vector3(0, 0, -1)) > 0.8:
			normal_counts["-Z (North)"] += 1
		elif n.dot(Vector3(1, 0, 0)) > 0.8:
			normal_counts["+X (East)"] += 1
		elif n.dot(Vector3(-1, 0, 0)) > 0.8:
			normal_counts["-X (West)"] += 1
		elif n.dot(Vector3(0, 1, 0)) > 0.8:
			normal_counts["+Y (Top)"] += 1
		elif n.dot(Vector3(0, -1, 0)) > 0.8:
			normal_counts["-Y (Bottom)"] += 1

	print("Wall normals: ", normal_counts)
	quit(0)
