extends SceneTree

func _init() -> void:
	print("--- Running test_mst_solver ---")
	var delaunay_script = preload("res://src/dungeon_generator/core/algorithms/delaunay_triangulator.gd")
	var mst_script = preload("res://src/dungeon_generator/core/algorithms/mst_solver.gd")

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
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Con 0.0 loop chance, debe producir exactamente N-1 aristas (MST puro = 4 aristas para 5 salas)
	var mst_edges: Array[Vector2i] = mst_script.solve(rooms.size(), edges, 0.0, rng)
	assert(mst_edges.size() == rooms.size() - 1, "Pure MST must have N-1 edges (expected 4, got %d)" % mst_edges.size())

	# Con 1.0 loop chance, debe incluir todas las aristas de Delaunay
	var full_edges: Array[Vector2i] = mst_script.solve(rooms.size(), edges, 1.0, rng)
	assert(full_edges.size() == edges.size(), "Full loop chance must keep all Delaunay edges")

	print("MST pure edges: %d | With full loops: %d" % [mst_edges.size(), full_edges.size()])
	print("[PASS] test_mst_solver succeeded.")
	quit(0)
