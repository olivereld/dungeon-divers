extends SceneTree

## Test de espaciado duro de entradas y distribución de caras en EntranceSolver (Fase 4 Refined).

const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("--- Running test_door_spacing (Task 6) ---")
	var grid := CellGrid.new(60, 60, CellGrid.CellType.WALL)

	# Habitación Hub central grande (14x14) conectada a dos salas (Norte y Este)
	var r_hub := RoomData.new(0, Rect2i(20, 20, 14, 14), &"hub")
	var r_north := RoomData.new(1, Rect2i(20, 4, 10, 8), &"north")
	var r_east := RoomData.new(2, Rect2i(42, 20, 8, 10), &"east")

	grid.fill_rect(r_hub.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r_north.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r_east.rect, CellGrid.CellType.FLOOR)

	var cfg := DungeonConfig.new()
	cfg.minimum_entrance_spacing = 4
	cfg.distribute_room_doors_across_sides = true
	cfg.same_side_door_penalty = 30.0

	var c_n = _RoomConnectionScript.new(0, 0, 1, true)
	var c_e = _RoomConnectionScript.new(1, 0, 2, true)

	var ent_res = _EntranceSolverScript.resolve([r_hub, r_north, r_east], [c_n, c_e], grid, cfg)
	assert(ent_res.is_valid, "Entrance resolution must succeed")
	assert(ent_res.entrance_pairs.size() == 2, "Must resolve 2 pairs")

	# Extraer las dos entradas asignadas a la sala Hub (room 0)
	var pair0 = ent_res.entrance_pairs[0]
	var pair1 = ent_res.entrance_pairs[1]

	var hub_ent_0 = pair0.entrance_a if pair0.entrance_a.room_id == 0 else pair0.entrance_b
	var hub_ent_1 = pair1.entrance_a if pair1.entrance_a.room_id == 0 else pair1.entrance_b

	# Test 1: Distribución entre caras distintas de la sala Hub
	assert(hub_ent_0.side != hub_ent_1.side, "Hub room doors must be distributed across different room sides (NORTH and EAST)")
	print("  [OK] Test 1: Side distribution across faces verified (Side 1=%d, Side 2=%d)" % [hub_ent_0.side, hub_ent_1.side])

	# Test 2: Espaciado duro (Hard spacing >= minimum_entrance_spacing)
	var dist_manhattan: int = absi(hub_ent_0.position.x - hub_ent_1.position.x) + absi(hub_ent_0.position.y - hub_ent_1.position.y)
	assert(dist_manhattan >= cfg.minimum_entrance_spacing, "Entrances on room perimeter must be at least minimum_entrance_spacing apart, got %d" % dist_manhattan)
	print("  [OK] Test 2: Hard entrance spacing verified (distance=%d >= %d)" % [dist_manhattan, cfg.minimum_entrance_spacing])

	# Test 3: Rechazo de candidatos a distancia < minimum_entrance_spacing en la misma cara
	var r_small := RoomData.new(0, Rect2i(10, 10, 8, 8), &"smallHub")
	var r_t1 := RoomData.new(1, Rect2i(8, 2, 6, 4), &"target1")
	var r_t2 := RoomData.new(2, Rect2i(14, 2, 6, 4), &"target2")
	var grid_small := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	grid_small.fill_rect(r_small.rect, CellGrid.CellType.FLOOR)
	grid_small.fill_rect(r_t1.rect, CellGrid.CellType.FLOOR)
	grid_small.fill_rect(r_t2.rect, CellGrid.CellType.FLOOR)

	var c_t1 = _RoomConnectionScript.new(0, 0, 1, true)
	var c_t2 = _RoomConnectionScript.new(1, 0, 2, true)
	var ent_res_small = _EntranceSolverScript.resolve([r_small, r_t1, r_t2], [c_t1, c_t2], grid_small, cfg)

	assert(ent_res_small.is_valid and ent_res_small.entrance_pairs.size() == 2, "Resolution must succeed")
	var p0_s = ent_res_small.entrance_pairs[0]
	var p1_s = ent_res_small.entrance_pairs[1]
	var h0 = p0_s.entrance_a if p0_s.entrance_a.room_id == 0 else p0_s.entrance_b
	var h1 = p1_s.entrance_a if p1_s.entrance_a.room_id == 0 else p1_s.entrance_b
	var d_small: int = absi(h0.position.x - h1.position.x) + absi(h0.position.y - h1.position.y)
	assert(d_small >= cfg.minimum_entrance_spacing, "Small room multiple doors must strictly obey minimum spacing")
	print("  [OK] Test 3: Multiple doors on constrained perimeter respect hard spacing (d=%d)" % d_small)

	print("[PASS] test_door_spacing completed successfully!")
	quit(0)
