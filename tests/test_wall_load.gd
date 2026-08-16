extends SceneTree

func _init() -> void:
	print("--- Checking wall.gltf and wall_corner.gltf ---")
	var wall_res = load("res://models/dungeon/wall/wall.gltf")
	print("Wall resource: ", wall_res)
	if wall_res is PackedScene:
		var inst = wall_res.instantiate()
		for child in inst.get_children():
			if child is MeshInstance3D:
				print("Wall Mesh: ", child.mesh.resource_name, " AABB: ", child.mesh.get_aabb())

	var corner_res = load("res://models/dungeon/wall_corner/wall_corner.gltf")
	print("Wall Corner resource: ", corner_res)
	if corner_res is PackedScene:
		var inst = corner_res.instantiate()
		for child in inst.get_children():
			if child is MeshInstance3D:
				print("Corner Mesh: ", child.mesh.resource_name, " AABB: ", child.mesh.get_aabb())

	quit(0)
