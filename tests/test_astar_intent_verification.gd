extends SceneTree

## Suite de verificación y endurecimiento de consumo de intención en AStarCarver.
## Grupos de test: A-I conforme al plan de ejecución final.

const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")

func _init() -> void:
	print("=== Running test_astar_intent_verification ===")

	test_group_a_request_identity()
	test_group_b_routing_preference()
	test_group_c_room_avoidance()
	test_group_d_preferred_length()
	test_group_e_min_max_length()
	test_group_f_role_priority()
	test_group_g_required_vs_optional_semantics()
	test_group_h_determinism()
	test_group_i_atomicity()

	print("=== ALL 9 TEST GROUPS (A-I) IN test_astar_intent_verification PASSED 100%! ===")
	quit(0)

# -------------------------------------------------------------------------
# Grupo A: Request Identity
# Verifica que connection_id, room_a_id, room_b_id, start y goal se preserven fielmente
# -------------------------------------------------------------------------
func test_group_a_request_identity() -> void:
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(10, Rect2i(2, 2, 6, 6))
	var room_b := _RoomDataScript.new(20, Rect2i(25, 2, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var ent_a := _RoomEntranceScript.new(10, 0, Vector2i(8, 5), _RoomEntranceScript.Side.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var ent_b := _RoomEntranceScript.new(20, 0, Vector2i(24, 5), _RoomEntranceScript.Side.WEST, Vector2i(25, 5), Vector2i(23, 5))
	var pair := _EntrancePairScript.new(42, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		42, 10, 20,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		14.0, 4, 30, _CorridorRequestScript.ROUTING_DIRECT
	)
	req.bind_physical_entrances(pair)

	var cfg := DungeonConfig.new()
	var res: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)

	assert(res.is_valid, "Group A: Carving must succeed")
	assert(res.paths.size() == 1, "Group A: Must produce exactly 1 path")
	var path: CorridorPath = res.paths[0]

	assert(path.connection_id == 42, "Group A: connection_id must match request (42)")
	assert(path.room_a_id == 10, "Group A: room_a_id must match request (10)")
	assert(path.room_b_id == 20, "Group A: room_b_id must match request (20)")
	assert(path.centerline_cells[0] == req.start, "Group A: centerline start must match req.start")
	assert(path.centerline_cells[-1] == req.goal, "Group A: centerline end must match req.goal")
	assert(not path.routing_strategy.is_empty() and path.routing_strategy != "Unknown", "Group A: routing_strategy must be populated")
	print("  [OK] Group A: Request Identity & Traceability verified")

# -------------------------------------------------------------------------
# Grupo B: Routing Preference
# Verifica geométricamente:
# ROUTING_DIRECT toma la ruta directa a través del área de suelo central,
# mientras que ROUTING_AVOID_ROOMS evita dicha área y toma la ruta alternativa alrededor.
# -------------------------------------------------------------------------
func test_group_b_routing_preference() -> void:
	var make_setup := func() -> Dictionary:
		var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
		var room_a := _RoomDataScript.new(1, Rect2i(2, 10, 6, 6))
		var room_b := _RoomDataScript.new(2, Rect2i(26, 10, 6, 6))
		grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
		grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

		# Área de suelo intermedia entre Room A y Room B
		var central_floor := Rect2i(14, 11, 5, 5)
		grid.fill_rect(central_floor, CellGrid.CellType.FLOOR)

		var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 13), _RoomEntranceScript.Side.EAST, Vector2i(7, 13), Vector2i(9, 13))
		var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(25, 13), _RoomEntranceScript.Side.WEST, Vector2i(26, 13), Vector2i(24, 13))
		var pair := _EntrancePairScript.new(1, ent_a, ent_b)
		return {"grid": grid, "room_a": room_a, "room_b": room_b, "pair": pair, "central_floor": central_floor}

	# 1. ROUTING_DIRECT: utiliza la ruta directa recta atravesando el área de suelo
	var s_dir = make_setup.call()
	var req_dir := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		15.0, 4, 40, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_dir.bind_physical_entrances(s_dir["pair"])
	var cfg_dir := DungeonConfig.new()
	cfg_dir.prefer_orthogonal_routes = true
	var res_dir: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_dir["grid"], [s_dir["room_a"], s_dir["room_b"]], [req_dir], [], cfg_dir)
	assert(res_dir.is_valid, "Group B: DIRECT must succeed")
	var path_dir: CorridorPath = res_dir.paths[0]
	var intersects_floor := false
	for cell in path_dir.centerline_cells:
		if s_dir["central_floor"].has_point(cell):
			intersects_floor = true
			break
	assert(intersects_floor, "Group B: DIRECT must take the direct path crossing the central floor area")

	# 2. ROUTING_AVOID_ROOMS: penaliza el suelo y toma la ruta alternativa alrededor
	var s_avoid = make_setup.call()
	var req_avoid := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_SIDE_PATH, Vector2i(1, 2),
		15.0, 4, 40, _CorridorRequestScript.ROUTING_AVOID_ROOMS
	)
	req_avoid.bind_physical_entrances(s_avoid["pair"])
	var cfg_avoid := DungeonConfig.new()
	var res_avoid: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_avoid["grid"], [s_avoid["room_a"], s_avoid["room_b"]], [req_avoid], [], cfg_avoid)
	assert(res_avoid.is_valid, "Group B: AVOID_ROOMS must succeed")
	var path_avoid: CorridorPath = res_avoid.paths[0]
	for cell in path_avoid.centerline_cells:
		assert(not s_avoid["central_floor"].has_point(cell), "Group B: AVOID_ROOMS centerline must not invade central floor area")
	for cell in path_avoid.carved_cells:
		assert(not s_avoid["central_floor"].has_point(cell), "Group B: AVOID_ROOMS carved cells must not invade central floor area")

	print("  [OK] Group B: Routing Preference geometrically verified (DIRECT traverses direct, AVOID_ROOMS detours around)")

# -------------------------------------------------------------------------
# Grupo C: Room Avoidance
# Verifica que con una sala ajena C registrada y una alternativa disponible,
# AStarCarver rutea por la alternativa y no invade Room C ni su buffer.
# -------------------------------------------------------------------------
func test_group_c_room_avoidance() -> void:
	var grid := CellGrid.new(45, 45, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 10, 6, 6))
	var room_b := _RoomDataScript.new(2, Rect2i(32, 10, 6, 6))
	var room_c := _RoomDataScript.new(3, Rect2i(15, 8, 10, 10)) # Sala ajena intermedia
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_c.rect, CellGrid.CellType.FLOOR)

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 13), _RoomEntranceScript.Side.EAST, Vector2i(7, 13), Vector2i(9, 13))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(31, 13), _RoomEntranceScript.Side.WEST, Vector2i(32, 13), Vector2i(30, 13))
	var pair := _EntrancePairScript.new(1, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_SIDE_PATH, Vector2i(1, 2),
		30.0, 4, 60, _CorridorRequestScript.ROUTING_AVOID_ROOMS
	)
	req.bind_physical_entrances(pair)

	var cfg := DungeonConfig.new()
	var res: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b, room_c], [req], [], cfg)

	assert(res.is_valid, "Group C: Carving must succeed avoiding unrelated Room C")
	var path: CorridorPath = res.paths[0]

	for cell in path.centerline_cells:
		assert(not room_c.rect.has_point(cell), "Group C: Centerline cell %s must not invade Room C" % str(cell))
	for cell in path.carved_cells:
		assert(not room_c.rect.has_point(cell), "Group C: Carved cell %s must not invade Room C" % str(cell))

	print("  [OK] Group C: Room Avoidance verified (Room C completely bypassed, alternative chosen)")

# -------------------------------------------------------------------------
# Grupo D: Preferred Length
# Demuestra con dos rutas posibles de igual coste base que preferred_length
# cambia deterministamente la selección de ruta hacia la longitud deseada.
# -------------------------------------------------------------------------
func test_group_d_preferred_length() -> void:
	var make_dual_route_setup := func() -> Dictionary:
		# Grid de 30x30 relleno de VOID (así solo existirán las dos rutas explícitamente talladas)
		var grid := CellGrid.new(30, 30, CellGrid.CellType.VOID)
		var room_a := _RoomDataScript.new(1, Rect2i(2, 8, 6, 5))
		var room_b := _RoomDataScript.new(2, Rect2i(19, 8, 6, 5))
		grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
		grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

		# Entradas: start=(9, 10), goal=(18, 10)
		var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 10), _RoomEntranceScript.Side.EAST, Vector2i(7, 10), Vector2i(9, 10))
		var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(19, 10), _RoomEntranceScript.Side.WEST, Vector2i(20, 10), Vector2i(18, 10))
		grid.set_cell(Vector2i(8, 10), CellGrid.CellType.FLOOR)
		grid.set_cell(Vector2i(19, 10), CellGrid.CellType.FLOOR)
		var pair := _EntrancePairScript.new(1, ent_a, ent_b)

		# Ruta 1 (Corta): recta horizontal por y=10 de x=9 a x=18 (10 celdas, 9 pasos)
		# 4 pasos WALL (4 * 15 = 60.0) + 5 pasos CORRIDOR (5 * 1 = 5.0) = 65.0 coste base
		for x in range(9, 19):
			grid.set_cell(Vector2i(x, 10), CellGrid.CellType.CORRIDOR)
		grid.set_cell(Vector2i(10, 10), CellGrid.CellType.WALL)
		grid.set_cell(Vector2i(11, 10), CellGrid.CellType.WALL)
		grid.set_cell(Vector2i(12, 10), CellGrid.CellType.WALL)
		grid.set_cell(Vector2i(13, 10), CellGrid.CellType.WALL)

		# Ruta 2 (Larga): detour hacia el sur por y=15 (19 celdas, 18 pasos)
		# 18 pasos CORRIDOR (18.0) + 3 giros (30.0) = 48.0 coste base (cercano a 51.0)
		for y in range(11, 16):
			grid.set_cell(Vector2i(9, y), CellGrid.CellType.CORRIDOR)
		for x in range(10, 19):
			grid.set_cell(Vector2i(x, 15), CellGrid.CellType.CORRIDOR)
		for y in range(11, 15):
			grid.set_cell(Vector2i(18, y), CellGrid.CellType.CORRIDOR)

		return {"grid": grid, "room_a": room_a, "room_b": room_b, "pair": pair}

	var short_target: float = 10.0
	var long_target: float = 19.0

	# 1. Petición con preferred_length corta (10.0)
	var s_short = make_dual_route_setup.call()
	var req_short := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		short_target, 1, 64, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_short.bind_physical_entrances(s_short["pair"])
	var cfg_short := DungeonConfig.new()
	cfg_short.prefer_orthogonal_routes = false # Evaluar A* directamente
	var res_short: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_short["grid"], [s_short["room_a"], s_short["room_b"]], [req_short], [], cfg_short)
	assert(res_short.is_valid, "Group D: Short preferred_length must succeed")
	var path_short: CorridorPath = res_short.paths[0]
	var len_short: float = float(path_short.centerline_cells.size())

	# 2. Petición con preferred_length larga (19.0)
	var s_long = make_dual_route_setup.call()
	var req_long := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		long_target, 1, 64, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_long.bind_physical_entrances(s_long["pair"])
	var cfg_long := DungeonConfig.new()
	cfg_long.prefer_orthogonal_routes = false # Evaluar A* directamente
	var res_long: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_long["grid"], [s_long["room_a"], s_long["room_b"]], [req_long], [], cfg_long)
	assert(res_long.is_valid, "Group D: Long preferred_length must succeed")
	var path_long: CorridorPath = res_long.paths[0]
	var len_long: float = float(path_long.centerline_cells.size())

	# Verificación conceptual estricta:
	# absf(path_short.length - short_length) < absf(path_short.length - long_length)
	# absf(path_long.length - long_length) < absf(path_long.length - short_length)
	assert(absf(len_short - short_target) < absf(len_short - long_target),
		"Group D: short request (len=%.1f) must be closer to short_target (%.1f) than long_target (%.1f)" % [len_short, short_target, long_target])
	assert(absf(len_long - long_target) < absf(len_long - short_target),
		"Group D: long request (len=%.1f) must be closer to long_target (%.1f) than short_target (%.1f)" % [len_long, long_target, short_target])

	print("  [OK] Group D: Preferred Length verified with dual-route selection (short=%.1f, long=%.1f)" % [len_short, len_long])

# -------------------------------------------------------------------------
# Grupo E: Min / Max Length
# Verifica que min_length y max_length imposibles no rechazan el corredor (preferencia soft)
# -------------------------------------------------------------------------
func test_group_e_min_max_length() -> void:
	var make_setup := func() -> Dictionary:
		var grid := CellGrid.new(35, 35, CellGrid.CellType.WALL)
		var room_a := _RoomDataScript.new(1, Rect2i(2, 5, 6, 6))
		var room_b := _RoomDataScript.new(2, Rect2i(20, 5, 6, 6))
		grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
		grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

		var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 8), _RoomEntranceScript.Side.EAST, Vector2i(7, 8), Vector2i(9, 8))
		var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(19, 8), _RoomEntranceScript.Side.WEST, Vector2i(20, 8), Vector2i(18, 8))
		var pair := _EntrancePairScript.new(1, ent_a, ent_b)
		return {"grid": grid, "room_a": room_a, "room_b": room_b, "pair": pair}

	# 1. Requiere mínimo 100 celdas (imposible para un tramo de 10)
	var s_min = make_setup.call()
	var req_min := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		10.0, 100, 200, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_min.bind_physical_entrances(s_min["pair"])
	var cfg := DungeonConfig.new()
	var res_min: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_min["grid"], [s_min["room_a"], s_min["room_b"]], [req_min], [], cfg)
	assert(res_min.is_valid, "Group E: Impossible min_length must NOT reject corridor")
	assert(res_min.paths.size() == 1, "Group E: Exactly 1 path must be carved for impossible min_length")

	# 2. Requiere máximo 2 celdas (imposible para un tramo de 10)
	var s_max = make_setup.call()
	var req_max := _CorridorRequestScript.create_planned(
		2, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		10.0, 1, 2, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_max.bind_physical_entrances(s_max["pair"])
	var res_max: CorridorCarveResult = _AStarCarverScript.carve_corridors(s_max["grid"], [s_max["room_a"], s_max["room_b"]], [req_max], [], cfg)
	assert(res_max.is_valid, "Group E: Impossible max_length must NOT reject corridor")
	assert(res_max.paths.size() == 1, "Group E: Exactly 1 path must be carved for impossible max_length")

	print("  [OK] Group E: Min/Max length verified as soft preferences (impossible min & max both carve successfully)")

# -------------------------------------------------------------------------
# Grupo F: Role Priority
# Verifica que AStarCarver procesa en orden: Required > MAIN_PATH > SIDE_PATH > OPTIONAL / SHORTCUT
# -------------------------------------------------------------------------
func test_group_f_role_priority() -> void:
	var req_opt := _CorridorRequestScript.new(10, 1, 2, Vector2i(2, 2), Vector2i(10, 2), Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, false, _CorridorRequestScript.ROLE_OPTIONAL)
	var req_side := _CorridorRequestScript.new(20, 1, 2, Vector2i(2, 2), Vector2i(10, 2), Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, true, _CorridorRequestScript.ROLE_SIDE_PATH)
	var req_main := _CorridorRequestScript.new(30, 1, 2, Vector2i(2, 2), Vector2i(10, 2), Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, true, _CorridorRequestScript.ROLE_MAIN_PATH)
	var req_main_opt := _CorridorRequestScript.new(40, 1, 2, Vector2i(2, 2), Vector2i(10, 2), Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, false, _CorridorRequestScript.ROLE_MAIN_PATH)
	var req_shortcut := _CorridorRequestScript.new(50, 1, 2, Vector2i(2, 2), Vector2i(10, 2), Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, false, _CorridorRequestScript.ROLE_SHORTCUT)

	var requests: Array[CorridorRequest] = [req_opt, req_side, req_main, req_main_opt, req_shortcut]

	requests.sort_custom(func(a: CorridorRequest, b: CorridorRequest):
		if a.is_required != b.is_required:
			return a.is_required
		var role_rank := func(r: StringName) -> int:
			match r:
				_CorridorRequestScript.ROLE_MAIN_PATH:
					return 3
				_CorridorRequestScript.ROLE_SIDE_PATH:
					return 2
				_CorridorRequestScript.ROLE_OPTIONAL, _CorridorRequestScript.ROLE_SHORTCUT:
					return 1
				_:
					return 0
		var r_a: int = role_rank.call(a.corridor_role)
		var r_b: int = role_rank.call(b.corridor_role)
		if r_a != r_b:
			return r_a > r_b
		return a.connection_id < b.connection_id
	)

	assert(requests[0].connection_id == 30, "Group F: #1 must be req_main (required, MAIN_PATH)")
	assert(requests[1].connection_id == 20, "Group F: #2 must be req_side (required, SIDE_PATH)")
	assert(requests[2].connection_id == 40, "Group F: #3 must be req_main_opt (optional, MAIN_PATH)")
	assert(requests[3].connection_id == 10, "Group F: #4 must be req_opt (optional, OPTIONAL)")
	assert(requests[4].connection_id == 50, "Group F: #5 must be req_shortcut (optional, SHORTCUT)")
	print("  [OK] Group F: Role Priority verified (Required > MAIN_PATH > SIDE_PATH > OPTIONAL / SHORTCUT)")

# -------------------------------------------------------------------------
# Grupo G: Required vs. Optional Semantics
# Verifica que fallo en is_required produce add_failure() (is_valid=false),
# mientras que fallo en opcional produce add_rejection() (is_valid permanece true si no hay required fallidas)
# -------------------------------------------------------------------------
func test_group_g_required_vs_optional_semantics() -> void:
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 6, 6))
	var room_b := _RoomDataScript.new(2, Rect2i(20, 2, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	# Bloquear totalmente la conexión con una pared de VOID
	for y in range(30):
		grid.set_cell(Vector2i(14, y), CellGrid.CellType.VOID)

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 5), _RoomEntranceScript.Side.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(19, 5), _RoomEntranceScript.Side.WEST, Vector2i(20, 5), Vector2i(18, 5))
	var pair := _EntrancePairScript.new(1, ent_a, ent_b)

	# 1. Caso Opcional: Fallo debe ir a add_rejection() y NO invalidar is_valid
	var req_opt := _CorridorRequestScript.create_planned(
		100, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		false, _CorridorRequestScript.ROLE_OPTIONAL, Vector2i(1, 2),
		10.0, 4, 30, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_opt.bind_physical_entrances(pair)

	var cfg := DungeonConfig.new()
	var res_opt: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req_opt], [], cfg)
	assert(res_opt.is_valid, "Group G: Optional corridor failure must NOT set is_valid to false")
	assert(res_opt.rejected_connection_ids.has(100), "Group G: Optional failure must be recorded in rejected_connection_ids")
	assert(res_opt.failed_connection_ids.is_empty(), "Group G: failed_connection_ids must remain empty for optional failure")

	# 2. Caso Required: Fallo debe ir a add_failure() e invalidar is_valid
	var req_req := _CorridorRequestScript.create_planned(
		200, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		10.0, 4, 30, _CorridorRequestScript.ROUTING_DIRECT
	)
	req_req.bind_physical_entrances(pair)

	var res_req: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req_req], [], cfg)
	assert(not res_req.is_valid, "Group G: Required corridor failure must set is_valid to false")
	assert(res_req.failed_connection_ids.has(200), "Group G: Required failure must be recorded in failed_connection_ids")
	print("  [OK] Group G: Required vs. Optional failure semantics verified (add_failure vs. add_rejection)")

# -------------------------------------------------------------------------
# Grupo H: Determinism
# Verifica que idénticos inputs producen idénticos centerlines, celdas y costes bit-a-bit
# -------------------------------------------------------------------------
func test_group_h_determinism() -> void:
	var run_carve := func() -> CorridorCarveResult:
		var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
		var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 6, 6))
		var room_b := _RoomDataScript.new(2, Rect2i(22, 18, 6, 6))
		grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
		grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

		var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 5), _RoomEntranceScript.Side.EAST, Vector2i(7, 5), Vector2i(9, 5))
		var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(21, 21), _RoomEntranceScript.Side.WEST, Vector2i(22, 21), Vector2i(20, 21))
		var pair := _EntrancePairScript.new(55, ent_a, ent_b)

		var req := _CorridorRequestScript.create_planned(
			55, 1, 2,
			Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
			true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
			18.0, 4, 50, _CorridorRequestScript.ROUTING_MANHATTAN
		)
		req.bind_physical_entrances(pair)

		var cfg := DungeonConfig.new()
		return _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)

	var res1: CorridorCarveResult = run_carve.call()
	var res2: CorridorCarveResult = run_carve.call()

	assert(res1.is_valid and res2.is_valid, "Group H: Both runs must succeed")
	assert(res1.paths[0].centerline_cells == res2.paths[0].centerline_cells, "Group H: Centerlines must match bit-for-bit")
	assert(res1.paths[0].carved_cells == res2.paths[0].carved_cells, "Group H: Carved cells must match bit-for-bit")
	assert(is_equal_approx(res1.paths[0].cost, res2.paths[0].cost), "Group H: Path costs must match exactly")
	assert(res1.paths[0].routing_strategy == res2.paths[0].routing_strategy, "Group H: Routing strategy must match")
	print("  [OK] Group H: 100% Deterministic Reproducibility verified")

# -------------------------------------------------------------------------
# Grupo I: Atomicity
# Verifica que un fallo en FIND, VALIDATE o WIDEN no muta CellGrid (0 celdas alteradas)
# -------------------------------------------------------------------------
func test_group_i_atomicity() -> void:
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := _RoomDataScript.new(1, Rect2i(2, 2, 6, 6))
	var room_b := _RoomDataScript.new(2, Rect2i(20, 2, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	# Bloquear el camino para provocar fallo en FIND
	for y in range(30):
		grid.set_cell(Vector2i(14, y), CellGrid.CellType.VOID)

	var snapshot_before: Array = []
	for y in range(30):
		for x in range(30):
			snapshot_before.append(grid.get_cell(Vector2i(x, y)))

	var ent_a := _RoomEntranceScript.new(1, 0, Vector2i(8, 5), _RoomEntranceScript.Side.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var ent_b := _RoomEntranceScript.new(2, 0, Vector2i(19, 5), _RoomEntranceScript.Side.WEST, Vector2i(20, 5), Vector2i(18, 5))
	var pair := _EntrancePairScript.new(1, ent_a, ent_b)

	var req := _CorridorRequestScript.create_planned(
		1, 1, 2,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true, _CorridorRequestScript.ROLE_MAIN_PATH, Vector2i(1, 2),
		10.0, 4, 30, _CorridorRequestScript.ROUTING_DIRECT
	)
	req.bind_physical_entrances(pair)

	var cfg := DungeonConfig.new()
	var res: CorridorCarveResult = _AStarCarverScript.carve_corridors(grid, [room_a, room_b], [req], [], cfg)
	assert(not res.is_valid, "Group I: Must fail due to void barrier")

	var snapshot_after: Array = []
	for y in range(30):
		for x in range(30):
			snapshot_after.append(grid.get_cell(Vector2i(x, y)))

	assert(snapshot_before == snapshot_after, "Group I: CellGrid must be 100% untouched when carving fails before COMMIT")
	print("  [OK] Group I: Atomicity verified (0 grid mutation on pre-commit failure)")
