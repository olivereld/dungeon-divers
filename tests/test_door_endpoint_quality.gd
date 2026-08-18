extends SceneTree

## Test de validación de endpoints y continuidad de puertas en DoorResolver (Fase 6 Refined).

const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")

func _init() -> void:
	print("--- Running test_door_endpoint_quality (Task 8) ---")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(5, 10, 6, 6), &"r1")
	var r2 := RoomData.new(1, Rect2i(25, 10, 6, 6), &"r2")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var cfg := DungeonConfig.new()
	var conn = _RoomConnectionScript.new(0, 0, 1, true)

	var ent_res = _EntranceSolverScript.resolve([r1, r2], [conn], grid, cfg)
	assert(ent_res.is_valid, "Entrance resolution must succeed")

	var carve_res = _AStarCarverScript.carve_corridors(grid, [r1, r2], ent_res.entrance_pairs, [conn], cfg)
	assert(carve_res.is_valid, "Corridor carving must succeed")
	var path: _CorridorPathScript = carve_res.paths[0]

	var door_res = _DoorResolverScript.resolve_doors(grid, [r1, r2], ent_res.entrance_pairs, carve_res.paths, [conn], cfg)
	assert(door_res.is_valid, "Door resolution must succeed")
	assert(door_res.door_pairs.size() == 1, "Must resolve 1 door pair")

	var dp = door_res.door_pairs[0]
	var da: DoorPlacement = dp.door_a
	var db: DoorPlacement = dp.door_b

	# Test 1: Comprobar que corridor_cell de las puertas sean exactamente los extremos de centerline
	var path_endpoints = [path.centerline_cells[0], path.centerline_cells[-1]]
	assert(da.corridor_cell in path_endpoints, "Door A corridor_cell must be an endpoint of centerline")
	assert(db.corridor_cell in path_endpoints, "Door B corridor_cell must be an endpoint of centerline")
	assert(da.corridor_cell != db.corridor_cell, "Door A and Door B must connect to opposite endpoints")
	print("  [OK] Test 1: Door corridor cells strictly correspond to path centerline endpoints")

	# Test 2: Validar que las celdas en el grid tengan CellType.DOOR
	assert(grid.get_cell(da.position) == CellGrid.CellType.DOOR, "Door A grid cell must be DOOR")
	assert(grid.get_cell(db.position) == CellGrid.CellType.DOOR, "Door B grid cell must be DOOR")
	print("  [OK] Test 2: Physical DOOR cell placement committed correctly")

	print("[PASS] test_door_endpoint_quality completed successfully!")
	quit(0)
