extends SceneTree

## Test unitario para Task 4: Buffer de Separación en AStar Corridor Carver.
## Valida que los corredores prefieran rutas con separación respecto a salas ajenas cuando hay espacio abierto.

func _init() -> void:
	print("--- Running test_corridor_clearance_buffer ---")
	var CarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
	var CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")

	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(2, 10, 6, 6), &"roomA")
	var room_b := RoomData.new(1, Rect2i(22, 10, 6, 6), &"roomB")
	# Sala ajena intermedia en (11, 10, 8, 6)
	var room_other := RoomData.new(2, Rect2i(11, 10, 8, 6), &"roomOther")

	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_other.rect, CellGrid.CellType.FLOOR)

	var rooms: Array[RoomData] = [room_a, room_b, room_other]
	var config := DungeonConfig.new()
	config.prefer_orthogonal_routes = false # Forzar A* direccional
	config.allow_astar_fallback = true

	var req = CorridorRequestScript.new(
		0, 0, 1,
		Vector2i(8, 13), Vector2i(21, 13),
		Vector2i(7, 13), Vector2i(22, 13),
		Vector2i(1, 0), Vector2i(-1, 0),
		true
	)

	var res = CarverScript.carve_corridors(grid, rooms, [req], [], config)
	assert(res != null and res.is_valid, "Corridor carving must succeed")
	assert(res.paths.size() == 1, "Must generate 1 path")

	var path = res.paths[0]
	# Comprobar que ningún punto del camino atraviese la sala ajena
	for pt in path.centerline_cells:
		assert(not room_other.rect.has_point(pt), "Path must not penetrate room_other at %s" % str(pt))

	print("  [OK] Corridor carver routes safely avoiding unrelated room collisions")
	print("[PASS] test_corridor_clearance_buffer completed successfully!")
	quit(0)
