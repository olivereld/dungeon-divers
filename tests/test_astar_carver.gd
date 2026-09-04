extends SceneTree

## Test directo de AStarCarver consumiendo CorridorRequest planificadas y vinculadas
## según el flujo formal: CorridorPlanner -> CorridorPlan -> EntranceSolver -> binding -> carve_corridors.

const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorPlannerScript = preload("res://src/dungeon_generator/core/planning/corridor_planner.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _SpatialIntentScript = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const _SpatialIntentResultScript = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")

func _init() -> void:
	print("--- Running test_astar_carver ---")

	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(5, 5, 8, 8), &"start")
	var room_b := RoomData.new(1, Rect2i(25, 25, 8, 8), &"goal")
	room_a.mission_node_id = 0
	room_b.mission_node_id = 1
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var rooms: Array[RoomData] = [room_a, room_b]
	var conn = _RoomConnectionScript.new(0, 0, 1, true)
	var connections: Array = [conn]

	# 1. Planificar intención con CorridorPlanner
	var intent_res := _SpatialIntentResultScript.new()
	intent_res.add_intent(_SpatialIntentScript.new(0, _SpatialIntentScript.ROLE_START, 0.0))
	intent_res.add_intent(_SpatialIntentScript.new(1, _SpatialIntentScript.ROLE_GOAL, 1.0))

	var planner := _CorridorPlannerScript.new()
	var plan = planner.plan_corridors(rooms, connections, null, intent_res)
	assert(plan != null and plan.size() == 1, "CorridorPlan must contain 1 request")

	# 2. Resolver geometría de entradas físicas puras con EntranceSolver
	var ent_res = _EntranceSolverScript.resolve(rooms, connections, grid)
	assert(ent_res.is_valid and ent_res.entrance_pairs.size() == 1, "Entrance resolution must succeed")

	# 3. Vincular entradas físicas y sellar el plan
	for pair in ent_res.entrance_pairs:
		var req = plan.get_request_for_connection(pair.connection_id)
		assert(req != null, "Request for connection must exist")
		req.bind_physical_entrances(pair)
	plan.seal()

	# 4. Tallar exclusivamente mediante CorridorRequest en AStarCarver
	var carve_res = _AStarCarverScript.carve_corridors(grid, rooms, plan.get_requests(), connections)
	assert(carve_res.is_valid, "Corridor carving must succeed")

	var corridors: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.CORRIDOR)
	assert(not corridors.is_empty(), "AStarCarver must carve corridors")

	print("AStarCarver carved %d corridor cells successfully" % corridors.size())
	print("[PASS] test_astar_carver succeeded.")
	quit(0)
