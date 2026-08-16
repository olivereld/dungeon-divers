extends SceneTree

func _init() -> void:
	print("--- Running test_astar_carver ---")
	var astar_carver_script = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")

	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(5, 5, 8, 8), &"start")
	var room_b := RoomData.new(1, Rect2i(25, 25, 8, 8), &"goal")
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var rooms: Array[RoomData] = [room_a, room_b]
	var connections: Array[Vector2i] = [Vector2i(0, 1)]

	astar_carver_script.carve_connections(grid, rooms, connections)

	var corridors: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.CORRIDOR)
	assert(not corridors.is_empty(), "AStarCarver must carve corridors")
	assert(not room_a.connections.is_empty(), "Room A must have recorded door connections")
	assert(not room_b.connections.is_empty(), "Room B must have recorded door connections")

	print("AStarCarver carved %d corridor cells successfully" % corridors.size())
	print("[PASS] test_astar_carver succeeded.")
	quit(0)
