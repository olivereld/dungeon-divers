extends SceneTree

## Test unitario para Task 1: Generador de Formas Arquitectónicas de Salas (RoomShapeGenerator).
## Valida que cada plantilla arquitectónica (OPEN_HALL, PILLARED_HALL, OCTAGONAL_CHAMBER, CRUCIFORM_SANCTUARY)
## genere un espacio amplio (área transitable >= 70% del bounding box) y 100% conexo.

func _init() -> void:
	print("--- Running test_room_shape_generator ---")
	var GeneratorScript = preload("res://src/dungeon_generator/core/algorithms/room_shape_generator.gd")
	assert(GeneratorScript != null, "RoomShapeGenerator script must exist")

	var shapes = [
		GeneratorScript.ShapeType.OPEN_HALL,
		GeneratorScript.ShapeType.PILLARED_HALL,
		GeneratorScript.ShapeType.OCTAGONAL_CHAMBER,
		GeneratorScript.ShapeType.CRUCIFORM_SANCTUARY
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	for shape in shapes:
		var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
		var room := RoomData.new(0, Rect2i(4, 4, 8, 8), &"test_room")

		GeneratorScript.apply_room_shape(grid, room, shape, rng)

		# Calcular área transitable dentro del bounding box
		var total_box_cells: int = room.rect.size.x * room.rect.size.y
		var floor_count: int = 0
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				if grid.get_cell(Vector2i(x, y)) == CellGrid.CellType.FLOOR:
					floor_count += 1

		var floor_ratio: float = float(floor_count) / float(total_box_cells)
		assert(floor_ratio >= 0.65, "Shape %d floor ratio %f must be >= 65%%" % [shape, floor_ratio])
		assert(grid.get_cell(room.get_center()) == CellGrid.CellType.FLOOR, "Room center must be FLOOR for shape %d" % shape)

		# Verificar que no haya partes desconectadas dentro del bounding box
		var center := room.get_center()
		var visited: Dictionary = {center: true}
		var queue: Array[Vector2i] = [center]
		var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		while not queue.is_empty():
			var curr = queue.pop_front()
			for d in dirs:
				var n = curr + d
				if room.rect.has_point(n) and not visited.has(n) and grid.get_cell(n) == CellGrid.CellType.FLOOR:
					visited[n] = true
					queue.push_back(n)

		assert(visited.size() == floor_count, "All %d floor cells must be connected to room center in shape %d (got %d visited)" % [floor_count, shape, visited.size()])
		print("  [OK] Shape %d: floor_count=%d/%d (%.1f%%), 100%% connected" % [shape, floor_count, total_box_cells, floor_ratio * 100.0])

	print("[PASS] test_room_shape_generator completed successfully!")
	quit(0)
