extends SceneTree

func _init() -> void:
	print("--- Detailed inspection of GLTF origins and dimensions ---")
	var floor_res = load("res://models/dungeon/floor_wood_small/floor_wood_small.gltf")
	var floor_node: Node3D = floor_res.instantiate()
	var floor_mesh: Mesh = floor_node.get_node("floor_wood_small").mesh
	print("Floor AABB: ", floor_mesh.get_aabb())

	var wall_res = load("res://models/dungeon/wall/wall.gltf")
	var wall_node: Node3D = wall_res.instantiate()
	var wall_mesh: Mesh = wall_node.get_node("wall").mesh
	print("Wall AABB: ", wall_mesh.get_aabb())

	var corner_res = load("res://models/dungeon/wall_corner/wall_corner.gltf")
	var corner_node: Node3D = corner_res.instantiate()
	var corner_mesh: Mesh = corner_node.get_node("wall_corner").mesh
	print("Corner AABB: ", corner_mesh.get_aabb())

	quit(0)
