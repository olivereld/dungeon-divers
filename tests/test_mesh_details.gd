extends SceneTree

func _init() -> void:
	var wall_res = load("res://models/dungeon/wall/wall.gltf")
	var inst: Node3D = wall_res.instantiate()
	var mesh_inst: MeshInstance3D = inst.get_node("wall")
	print("Wall Mesh AABB: ", mesh_inst.mesh.get_aabb())

	var corner_res = load("res://models/dungeon/wall_corner/wall_corner.gltf")
	var c_inst: Node3D = corner_res.instantiate()
	var c_mesh_inst: MeshInstance3D = c_inst.get_node("wall_corner")
	print("Corner Mesh AABB: ", c_mesh_inst.mesh.get_aabb())

	quit(0)
