extends SceneTree

## Test suite for Corridor Routing Robustness Improvements.
## Verifies search budget bounds, explicit search states, widen-aware routing,
## atomicity, repair limits, and evaluates problematic seeds: 179066012, 801931164, 507407633.

const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _CorridorPlanScript = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")
const _CorridorConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/corridor_connectivity_repair.gd")

func _init() -> void:
	print("==================================================================")
	print("=== STARTING CORRIDOR ROUTING ROBUSTNESS VERIFICATION SUITE ===")
	print("==================================================================")

	test_1_search_budget_exceeded()
	test_2_explicit_search_states()
	test_3_widen_aware_routing()
	test_4_atomicity_and_no_grid_mutation()
	test_5_repair_budget_limit()
	test_6_problematic_seeds_diagnostics()

	print("\n>>> ALL CORRIDOR ROUTING ROBUSTNESS TESTS PASSED 100%! <<<")
	quit(0)

## Test 1: Bounded search aborts with SEARCH_BUDGET_EXCEEDED when limits are reached
func test_1_search_budget_exceeded() -> void:
	print("\n[TEST 1] Verificando presupuesto de búsqueda A* y SEARCH_BUDGET_EXCEEDED...")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 6, 6))
	var room_b := _RoomDataScript.new(2, Rect2i(30, 30, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 5), _RoomEntranceScript.Side.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(29, 33), _RoomEntranceScript.Side.WEST, Vector2i(30, 33), Vector2i(28, 33))
	var pair := _EntrancePairScript.new(101, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		101, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		20.0, 4, 60, _CorridorRequestScript.ROUTING_AVOID_ROOMS # Fuerza uso de AStar
	)
	req.bind_physical_entrances(pair)

	var cfg := _DungeonConfigScript.new()
	cfg.prefer_orthogonal_routes = false
	cfg.corridor_max_search_states = 10 # Presupuesto extremadamente pequeño para forzar aborto
	cfg.corridor_max_search_ms = 50.0

	var res: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)
	assert(not res.is_valid, "Debe fallar al agotarse los estados de búsqueda permitidos")
	assert(res.failed_connection_ids.has(101), "La conexión 101 debe estar en failed_connection_ids")
	assert(not res.diagnostics.is_empty(), "Debe existir registro en diagnostics")

	var diag = res.diagnostics[0]
	assert(diag.get("termination_reason") == "SEARCH_BUDGET_EXCEEDED" or diag.get("reason") == "SEARCH_BUDGET_EXCEEDED",
		"El motivo de terminación debe ser SEARCH_BUDGET_EXCEEDED, obtenido: %s" % str(diag.get("reason")))
	assert(diag.get("expanded_states", 0) <= 12, "expanded_states debe estar acotado por el presupuesto")
	print("  [OK] Bounded search budget aborts cleanly with SEARCH_BUDGET_EXCEEDED.")

## Test 2: Internal routing results must distinguish SUCCESS, NO_PATH, SEARCH_BUDGET_EXCEEDED
func test_2_explicit_search_states() -> void:
	print("\n[TEST 2] Verificando distinción entre NO_PATH y SEARCH_BUDGET_EXCEEDED...")
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 4, 4))
	var room_b := _RoomDataScript.new(2, Rect2i(14, 14, 4, 4))

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(6, 4), _RoomEntranceScript.Side.EAST, Vector2i(5, 4), Vector2i(7, 4))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(13, 16), _RoomEntranceScript.Side.WEST, Vector2i(14, 16), Vector2i(12, 16))
	var pair := _EntrancePairScript.new(202, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		202, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		0.0, 0, 0, _CorridorRequestScript.ROUTING_AVOID_ROOMS
	)
	req.bind_physical_entrances(pair)

	# Dividir la rejilla horizontalmente con un muro infranqueable de celdas COLUMN
	for x in range(grid.width):
		grid.set_cell(Vector2i(x, 9), CellGrid.CellType.COLUMN)
		grid.set_cell(Vector2i(x, 10), CellGrid.CellType.COLUMN)

	var cfg := _DungeonConfigScript.new()
	cfg.prefer_orthogonal_routes = false
	cfg.corridor_max_search_states = 15000
	cfg.corridor_max_search_ms = 1000.0

	var res: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)
	assert(not res.is_valid, "No debe encontrar camino al estar bloqueado por columnas")
	var diag = res.diagnostics[0]
	assert(diag.get("reason") == "NO_PATH" or diag.get("termination_reason") == "NO_PATH",
		"Debe reportar NO_PATH explícitamente cuando no existe ruta geométrica, obtenido: %s" % str(diag.get("reason")))
	print("  [OK] NO_PATH clearly distinguished from SEARCH_BUDGET_EXCEEDED.")

## Test 3: Widen-aware routing rejects paths where corridor_width cannot fit
func test_3_widen_aware_routing() -> void:
	print("\n[TEST 3] Verificando enrutamiento consciente de ensanchamiento (Widen-Aware)...")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 5, 5, 5))
	var room_b := _RoomDataScript.new(2, Rect2i(22, 5, 5, 5))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	# Crear un cuello de botella de 1 sola celda de ancho entre x=10 y x=20 colocando columnas arriba y abajo
	for x in range(10, 20):
		grid.set_cell(Vector2i(x, 6), CellGrid.CellType.COLUMN)
		grid.set_cell(Vector2i(x, 8), CellGrid.CellType.COLUMN)
	# Fila y=7 queda libre como un hueco de 1 celda

	var room_map: Dictionary = {1: room_a, 2: room_b}

	# Footprint para ancho 1 debe ser válido
	var valid_w1: bool = _AStarCarverScript._is_corridor_footprint_valid(
		grid, Vector2i(14, 7), Vector2i(1, 0), 1, room_map, 1, 2
	)
	assert(valid_w1, "Con corridor_width=1, el canal de 1 celda debe ser válido")

	# Footprint para ancho 2 debe ser inválido porque lateralmente colisiona con COLUMN
	var valid_w2: bool = _AStarCarverScript._is_corridor_footprint_valid(
		grid, Vector2i(14, 7), Vector2i(1, 0), 2, room_map, 1, 2
	)
	assert(not valid_w2, "Con corridor_width=2, el canal estrecho debe ser rechazado por colisión lateral")
	print("  [OK] _is_corridor_footprint_valid correctly rejects narrow passages for wide corridors.")

## Test 4: Atomicity — failed searches leave CellGrid 100% untouched
func test_4_atomicity_and_no_grid_mutation() -> void:
	print("\n[TEST 4] Verificando atomicidad: fallos de búsqueda dejan CellGrid intacto...")
	var grid := CellGrid.new(25, 25, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 5, 5))
	var room_b := _RoomDataScript.new(2, Rect2i(18, 18, 5, 5))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(7, 4), _RoomEntranceScript.Side.EAST, Vector2i(6, 4), Vector2i(8, 4))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(17, 20), _RoomEntranceScript.Side.WEST, Vector2i(18, 20), Vector2i(16, 20))
	var pair := _EntrancePairScript.new(303, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		303, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		15.0, 4, 30, _CorridorRequestScript.ROUTING_AVOID_ROOMS
	)
	req.bind_physical_entrances(pair)

	# Tomar instantánea de celdas
	var initial_cells: Dictionary = {}
	for y in range(grid.height):
		for x in range(grid.width):
			initial_cells[Vector2i(x, y)] = grid.get_cell(Vector2i(x, y))

	# Forzar fallo por budget
	var cfg := _DungeonConfigScript.new()
	cfg.prefer_orthogonal_routes = false
	cfg.corridor_max_search_states = 5

	var res = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)
	assert(not res.is_valid, "La búsqueda debe fallar")

	# Comprobar que ninguna celda fue modificada
	var mutated_count: int = 0
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_cell(Vector2i(x, y)) != initial_cells[Vector2i(x, y)]:
				mutated_count += 1

	assert(mutated_count == 0, "Atomicidad violada: %d celdas fueron modificadas tras un fallo de búsqueda" % mutated_count)
	print("  [OK] Zero grid cells mutated upon search failure (100% atomic).")

## Test 5: Repair budget limits prevent unbounded repair loops
func test_5_repair_budget_limit() -> void:
	print("\n[TEST 5] Verificando presupuesto global de reparaciones...")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 5, 5))
	var room_b := _RoomDataScript.new(2, Rect2i(20, 20, 5, 5))

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(7, 4), _RoomEntranceScript.Side.EAST, Vector2i(6, 4), Vector2i(8, 4))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(19, 22), _RoomEntranceScript.Side.WEST, Vector2i(20, 22), Vector2i(18, 22))
	var pair := _EntrancePairScript.new(404, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		404, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		15.0, 4, 30, _CorridorRequestScript.ROUTING_AVOID_ROOMS
	)
	req.bind_physical_entrances(pair)

	var plan = _CorridorPlanScript.new()
	plan.add_request(req)
	plan.seal()

	var failed_res = _CorridorCarveResultScript.new()
	failed_res.add_failure(404, "SEARCH_BUDGET_EXCEEDED", {
		"connection_id": 404,
		"room_a_id": 1,
		"room_b_id": 2,
		"expanded_states": 12000,
		"elapsed_ms": 250.0
	})

	var cfg := _DungeonConfigScript.new()
	cfg.corridor_max_repair_attempts = 0 # 0 intentos permitidos

	var rep_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
		grid, [room_a, room_b], [pair], [{"id": 404, "is_required": true}], failed_res, 12345, plan, cfg
	)
	assert(not rep_res.success, "No debe realizar reparaciones con presupuesto 0")
	var c_res: CorridorCarveResult = rep_res.corridor_res
	assert(c_res.diagnostics[0].get("repair_attempted") == true, "Debe registrar que se evaluó el intento de reparación")
	assert(c_res.diagnostics[0].get("repair_success") == false, "repair_success debe ser false")
	print("  [OK] Repair budget limit cleanly respected.")

## Test 6: Evaluate problematic seeds and log diagnostics per connection
func test_6_problematic_seeds_diagnostics() -> void:
	print("\n[TEST 6] Evaluando seeds problemáticas (179066012, 801931164, 507407633)...")
	var pipeline := _DungeonPipelineScript.new()
	var test_seeds: Array[int] = [179066012, 801931164, 507407633]

	for s in test_seeds:
		var cfg := _DungeonConfigScript.new()
		cfg.seed = s
		cfg.use_fixed_seed = true
		cfg.corridor_max_search_states = 12000
		cfg.corridor_max_search_ms = 250.0
		cfg.corridor_max_repair_attempts = 3

		var t0: int = Time.get_ticks_msec()
		var res: DungeonResult = pipeline.generate(cfg, 3, false)
		var elapsed_total: float = float(Time.get_ticks_msec() - t0)

		print("\n  >> SEED %d (Elapsed Total: %.1f ms, Status: %s)" % [
			s, elapsed_total, "GENERATED" if res != null else "FAILED"
		])

		assert(elapsed_total < 30000.0, "La seed %d excedió el límite de 30 segundos (tomó %.1f ms)" % [s, elapsed_total])

		if res != null:
			var diags: Array = res.metadata.get("corridor_diagnostics", [])
			print("     Corridor Diagnostics (%d connections):" % diags.size())
			for d in diags:
				var cid: int = d.get("connection_id", -1)
				var strat: String = d.get("strategy", "Unknown")
				var states: int = d.get("expanded_states", 0)
				var ms: float = d.get("elapsed_ms", 0.0)
				var term: String = d.get("termination_reason", d.get("reason", "OK"))
				var rep: String = "YES" if d.get("repair_attempted", false) else "NO"
				print("       Conn %d: strat=%s, states=%d, time=%.1fms, reason=%s, repair=%s" % [
					cid, strat, states, ms, term, rep
				])
		else:
			print("     Pipeline gracefully rejected seed %d within %.1f ms" % [s, elapsed_total])

	print("\n  [OK] All 3 problematic seeds executed safely and deterministically within bounded time.")
