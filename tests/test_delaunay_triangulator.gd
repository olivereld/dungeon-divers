extends SceneTree

func _init() -> void:
	print("--- Running test_delaunay_triangulator ---")
	var delaunay_script = preload("res://src/dungeon_generator/core/algorithms/delaunay_triangulator.gd")

	# Test con 5 habitaciones
	var rooms: Array[RoomData] = []
	var centers := [
		Vector2i(10, 10),
		Vector2i(30, 10),
		Vector2i(10, 30),
		Vector2i(30, 30),
		Vector2i(20, 20)
	]
	for i in range(centers.size()):
		var r := RoomData.new(i, Rect2i(centers[i].x - 3, centers[i].y - 3, 6, 6))
		rooms.append(r)

	var edges: Array = delaunay_script.triangulate(rooms)
	assert(not edges.is_empty(), "Delaunay must produce edges")
	print("Delaunay produced %d edges for 5 rooms" % edges.size())

	# Verificar que no haya aristas con índices fuera de límites
	for edge in edges:
		assert(edge.u >= 0 and edge.u < rooms.size(), "Edge u must be valid")
		assert(edge.v >= 0 and edge.v < rooms.size(), "Edge v must be valid")
		assert(edge.u != edge.v, "No self loops")
		assert(edge.weight > 0.0, "Weight must be positive")

	print("[PASS] test_delaunay_triangulator succeeded.")
	quit(0)
