extends SceneTree

## Test de contratos e invariantes de CorridorPlan y CorridorRequest (Boundary Refactor Verification).

const _CorridorPlanScript = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("--- Running test_corridor_plan_and_request_invariants ---")

	# Test 1: Creación planificada de CorridorRequest con intención semántica
	var req := _CorridorRequestScript.create_planned(
		0, 10, 20,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO,
		true,
		_CorridorRequestScript.ROLE_MAIN_PATH,
		Vector2i(1, 2),
		18.5,
		4,
		64,
		_CorridorRequestScript.ROUTING_DIRECT
	)
	assert(req.connection_id == 0, "Connection ID must be 0")
	assert(req.room_a_id == 10 and req.room_b_id == 20, "Room IDs must match")
	assert(req.corridor_role == _CorridorRequestScript.ROLE_MAIN_PATH, "Role must be main_path")
	assert(req.routing_preference == _CorridorRequestScript.ROUTING_DIRECT, "Routing must be direct")
	assert(is_equal_approx(req.preferred_length, 18.5), "Preferred length must be 18.5")
	assert(not req.is_sealed(), "Must be unsealed initially")
	print("  [OK] Test 1: CorridorRequest created with semantic intent")

	# Test 2: Vinculación física pura de EntrancePair (sin mutar intención semántica)
	var ent_a := _RoomEntranceScript.new(10, 0, Vector2i(15, 10), _RoomEntranceScript.Side.EAST, Vector2i(14, 10), Vector2i(16, 10))
	var ent_b := _RoomEntranceScript.new(20, 0, Vector2i(25, 10), _RoomEntranceScript.Side.WEST, Vector2i(26, 10), Vector2i(24, 10))
	var pair := _EntrancePairScript.new(0, ent_a, ent_b, 5.0)

	req.bind_physical_entrances(pair)
	assert(req.start == Vector2i(16, 10), "start must be outer_cell of entrance_a")
	assert(req.goal == Vector2i(24, 10), "goal must be outer_cell of entrance_b")
	assert(req.start_boundary == Vector2i(15, 10), "start_boundary must be boundary_cell of entrance_a")
	assert(req.goal_boundary == Vector2i(25, 10), "goal_boundary must be boundary_cell of entrance_b")
	assert(req.start_inner == Vector2i(14, 10), "start_inner must be inner_cell of entrance_a")
	assert(req.goal_inner == Vector2i(26, 10), "goal_inner must be inner_cell of entrance_b")
	assert(req.start_direction == Vector2i(1, 0), "start_direction must be outward direction of EAST")
	assert(req.goal_direction == Vector2i(-1, 0), "goal_direction must be outward direction of WEST")
	# preferred_length NO debe ser sobreescrito por la distancia física
	assert(is_equal_approx(req.preferred_length, 18.5), "bind_physical_entrances must NOT alter preferred_length")
	print("  [OK] Test 2: bind_physical_entrances bound physical cells without mutating intent")

	# Test 3: Inmutabilidad estricta tras CorridorPlan.seal()
	var plan := _CorridorPlanScript.new()
	plan.add_request(req)
	assert(not plan.is_sealed(), "Plan must be unsealed before seal()")
	assert(plan.get_request_for_connection(0) == req, "Must retrieve request by conn_id")

	plan.seal()
	assert(plan.is_sealed(), "Plan must be sealed")
	assert(req.is_sealed(), "Request must be sealed after plan.seal()")
	print("  [OK] Test 3: CorridorPlan and CorridorRequest sealing verified")

	# Test 4: Verificación de ausencia de API obsoleta (from_entrance_pair, aliases)
	assert(not req.has_method("from_entrance_pair"), "from_entrance_pair must NOT exist on CorridorRequest")
	assert(not ("preferred_entrance" in req), "preferred_entrance alias must NOT exist")
	assert(not ("preferred_exit" in req), "preferred_exit alias must NOT exist")
	assert(not ("from_room" in req), "from_room alias must NOT exist")
	assert(not ("to_room" in req), "to_room alias must NOT exist")
	print("  [OK] Test 4: Obsolete APIs and aliases confirmed eliminated")

	print("[PASS] test_corridor_plan_and_request_invariants completed successfully!")
	quit(0)
