extends SceneTree

const CompositionStrategy = preload("res://src/dungeon_generator/core/grammars/composition_strategy.gd")
const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialCompositionBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_composition_builder.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

func _init() -> void:
	print("--- Running test_composition_strategy_global ---")

	test_direct_spatial_composition_input()
	test_hard_constraints_enforcement()
	test_main_path_alignment_and_monotonicity()
	test_branch_lateral_offset_and_separation()
	test_non_mutating_contract_and_sealing()

	print("[PASS] All CompositionStrategy global guidance tests passed successfully!")
	quit(0)

func test_direct_spatial_composition_input() -> void:
	print("  Testing direct SpatialComposition input to CompositionStrategy...")
	var bounds := Rect2i(0, 0, 80, 80)
	var comp := SpatialComposition.new()
	comp.set_progression_direction(Vector2(1, 0))

	# Main path nodes: 0 (START) -> 1 (MID) -> 2 (BOSS)
	comp.set_main_path_node(0, 0.0, Vector2(15, 40))
	comp.set_main_path_node(1, 0.5, Vector2(40, 40))
	comp.set_main_path_node(2, 1.0, Vector2(65, 40))
	comp.set_node_region(0, SpatialComposition.REGION_START)
	comp.set_node_region(1, SpatialComposition.REGION_MID)
	comp.set_node_region(2, SpatialComposition.REGION_BOSS)
	comp.set_node_density(0, 1.0)
	comp.set_node_density(1, 1.0)
	comp.set_node_density(2, 1.2)

	# Branch node 3 anchored to 1, target offset laterally
	comp.set_branch_node(3, 1, 0.55, Vector2(40, 60))
	comp.set_node_region(3, SpatialComposition.REGION_BRANCH)
	comp.set_node_density(3, 0.8)
	comp.seal()

	var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), RoomData.RoomType.START)
	r0.mission_node_id = 0
	var r1 := RoomData.new(1, Rect2i(0, 0, 8, 8), RoomData.RoomType.EXPLORE)
	r1.mission_node_id = 1
	var r2 := RoomData.new(2, Rect2i(0, 0, 10, 10), RoomData.RoomType.BOSS)
	r2.mission_node_id = 2
	var r3 := RoomData.new(3, Rect2i(0, 0, 6, 6), RoomData.RoomType.EXPLORE)
	r3.mission_node_id = 3

	var rooms: Array[RoomData] = [r0, r1, r2, r3]
	var strategy := CompositionStrategy.new(RandomNumberGenerator.new())

	# Pass SpatialComposition directly as 5th argument
	var plan: RoomPlacementPlan = strategy.create_placement_plan(rooms, null, bounds, null, comp)

	assert(plan != null, "Plan must not be null")
	assert(plan.is_sealed(), "Plan must be sealed")
	assert(plan.size() == 4, "All 4 rooms must be successfully placed")

	# Check that positions conform to SpatialComposition targets
	var pos0: Vector2i = plan.get_position(0)
	var pos1: Vector2i = plan.get_position(1)
	var pos2: Vector2i = plan.get_position(2)
	var pos3: Vector2i = plan.get_position(3)

	# r0 (START) should be placed near (15, 40)
	var c0 := Vector2(pos0) + Vector2(r0.rect.size) / 2.0
	assert(c0.distance_to(Vector2(15, 40)) < 12.0, "Room 0 should be near its target (15, 40), got %s" % str(c0))

	# r2 (BOSS) should be placed near (65, 40)
	var c2 := Vector2(pos2) + Vector2(r2.rect.size) / 2.0
	assert(c2.distance_to(Vector2(65, 40)) < 14.0, "Room 2 should be near its target (65, 40), got %s" % str(c2))

	# r3 (Branch) should have lateral offset near (40, 60)
	var c3 := Vector2(pos3) + Vector2(r3.rect.size) / 2.0
	assert(c3.y > c0.y + 4.0, "Room 3 must be laterally displaced in Y relative to START, got y=%f vs %f" % [c3.y, c0.y])

	print("  -> Passed direct SpatialComposition input test.")

func test_hard_constraints_enforcement() -> void:
	print("  Testing hard constraints (bounds, min separation, START/BOSS distance)...")
	var bounds := Rect2i(5, 5, 50, 50)
	var config := SpaceGrammarConfig.new()
	config.min_room_separation = 3
	config.min_mission_edge_distance = 6.0

	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START", {"action": MissionNode.ActionType.START})
	var n1: int = graph.add_node(&"EXPLORE", {"action": MissionNode.ActionType.EXPLORE})
	var n2: int = graph.add_node(&"BOSS", {"action": MissionNode.ActionType.BOSS})
	graph.add_edge(n0, n1)
	graph.add_edge(n1, n2)

	var r0 := RoomData.new(0, Rect2i(0, 0, 8, 8), RoomData.RoomType.START)
	r0.mission_node_id = n0
	var r1 := RoomData.new(1, Rect2i(0, 0, 8, 8), RoomData.RoomType.EXPLORE)
	r1.mission_node_id = n1
	var r2 := RoomData.new(2, Rect2i(0, 0, 10, 10), RoomData.RoomType.BOSS)
	r2.mission_node_id = n2

	var strategy := CompositionStrategy.new()
	var plan: RoomPlacementPlan = strategy.create_placement_plan([r0, r1, r2], graph, bounds, config)

	assert(plan.size() == 3, "All 3 rooms must be placed")

	var rects: Dictionary = {}
	for r in [r0, r1, r2]:
		var p: Vector2i = plan.get_position(r.id)
		var rect := Rect2i(p, r.rect.size)
		rects[r.id] = rect

		# 1. Bounds check
		assert(bounds.encloses(rect), "Room %d rect %s must be inside bounds %s" % [r.id, str(rect), str(bounds)])

	# 2. Min separation check
	for id_a in rects:
		for id_b in rects:
			if id_a >= id_b:
				continue
			var ra: Rect2i = rects[id_a]
			var rb: Rect2i = rects[id_b]
			assert(not ra.intersects(rb.grow(config.min_room_separation)), "Rooms %d and %d must satisfy min separation %d" % [id_a, id_b, config.min_room_separation])

	# 3. BOSS / START distance
	var c_start: Vector2 = Vector2(rects[r0.id].position) + Vector2(rects[r0.id].size) / 2.0
	var c_boss: Vector2 = Vector2(rects[r2.id].position) + Vector2(rects[r2.id].size) / 2.0
	assert(c_boss.distance_to(c_start) >= config.min_mission_edge_distance * 1.8, "BOSS must be at least min_edge_dist * 1.8 from START")

	print("  -> Passed hard constraints enforcement test.")

func test_main_path_alignment_and_monotonicity() -> void:
	print("  Testing Main Path progression alignment and monotonicity...")
	var graph := DungeonGraph.new()
	var n_start: int = graph.add_node(&"START", {"action": MissionNode.ActionType.START})
	var n_1: int = graph.add_node(&"EXPLORE", {"action": MissionNode.ActionType.EXPLORE})
	var n_2: int = graph.add_node(&"FIND_KEY", {"action": MissionNode.ActionType.FIND_KEY})
	var n_3: int = graph.add_node(&"UNLOCK", {"action": MissionNode.ActionType.UNLOCK})
	var n_boss: int = graph.add_node(&"BOSS", {"action": MissionNode.ActionType.BOSS})

	graph.add_edge(n_start, n_1)
	graph.add_edge(n_1, n_2)
	graph.add_edge(n_2, n_3)
	graph.add_edge(n_3, n_boss)

	var rooms: Array[RoomData] = [
		RoomData.new(0, Rect2i(0, 0, 6, 6), RoomData.RoomType.START),
		RoomData.new(1, Rect2i(0, 0, 6, 6), RoomData.RoomType.EXPLORE),
		RoomData.new(2, Rect2i(0, 0, 6, 6), RoomData.RoomType.EXPLORE),
		RoomData.new(3, Rect2i(0, 0, 6, 6), RoomData.RoomType.EXPLORE),
		RoomData.new(4, Rect2i(0, 0, 8, 8), RoomData.RoomType.BOSS)
	]
	rooms[0].mission_node_id = n_start
	rooms[1].mission_node_id = n_1
	rooms[2].mission_node_id = n_2
	rooms[3].mission_node_id = n_3
	rooms[4].mission_node_id = n_boss

	var bounds := Rect2i(0, 0, 100, 100)
	var config := SpaceGrammarConfig.new()
	config.preferred_progression_direction = Vector2(1, 0) # strictly east

	var strategy := CompositionStrategy.new()
	var plan: RoomPlacementPlan = strategy.create_placement_plan(rooms, graph, bounds, config)

	assert(plan.size() == 5, "All 5 main path rooms must be placed")

	var c_start: Vector2 = Vector2(plan.get_position(0)) + Vector2(rooms[0].rect.size) / 2.0
	var c_boss: Vector2 = Vector2(plan.get_position(4)) + Vector2(rooms[4].rect.size) / 2.0

	# Eastward progression: c_boss.x must be significantly greater than c_start.x
	assert(c_boss.x > c_start.x + 25.0, "BOSS must be well eastward of START along preferred direction, got %f vs %f" % [c_boss.x, c_start.x])

	# Monotonicity: projection along (1, 0) generally increases from start to boss
	var prev_proj: float = -INF
	for i in range(rooms.size()):
		var c: Vector2 = Vector2(plan.get_position(i)) + Vector2(rooms[i].rect.size) / 2.0
		var proj: float = c.x
		# Check overall advancement
		assert(proj >= prev_proj - 4.0, "Room %d projection (%f) should not significantly regress from previous (%f)" % [i, proj, prev_proj])
		prev_proj = proj

	print("  -> Passed Main Path alignment and monotonicity test.")

func test_branch_lateral_offset_and_separation() -> void:
	print("  Testing Branch lateral offset, main path separation and avoiding squeeze...")
	var graph := DungeonGraph.new()
	var n_start: int = graph.add_node(&"START", {"action": MissionNode.ActionType.START})
	var n_mid: int = graph.add_node(&"EXPLORE", {"action": MissionNode.ActionType.EXPLORE})
	var n_boss: int = graph.add_node(&"BOSS", {"action": MissionNode.ActionType.BOSS})
	var n_branch: int = graph.add_node(&"TREASURE", {"action": MissionNode.ActionType.TREASURE, "is_optional": true})

	graph.add_edge(n_start, n_mid)
	graph.add_edge(n_mid, n_boss)
	graph.add_edge(n_mid, n_branch)

	var rooms: Array[RoomData] = [
		RoomData.new(0, Rect2i(0, 0, 6, 6), RoomData.RoomType.START),
		RoomData.new(1, Rect2i(0, 0, 6, 6), RoomData.RoomType.EXPLORE),
		RoomData.new(2, Rect2i(0, 0, 8, 8), RoomData.RoomType.BOSS),
		RoomData.new(3, Rect2i(0, 0, 6, 6), RoomData.RoomType.TREASURE)
	]
	rooms[0].mission_node_id = n_start
	rooms[1].mission_node_id = n_mid
	rooms[2].mission_node_id = n_boss
	rooms[3].mission_node_id = n_branch

	var bounds := Rect2i(0, 0, 90, 90)
	var config := SpaceGrammarConfig.new()
	config.preferred_progression_direction = Vector2(1, 0) # Main path runs in X

	var strategy := CompositionStrategy.new()
	var plan: RoomPlacementPlan = strategy.create_placement_plan(rooms, graph, bounds, config)

	assert(plan.size() == 4, "All 4 rooms must be placed")

	var c_mid: Vector2 = Vector2(plan.get_position(1)) + Vector2(rooms[1].rect.size) / 2.0
	var c_branch: Vector2 = Vector2(plan.get_position(3)) + Vector2(rooms[3].rect.size) / 2.0

	# Lateral offset: since progression is in X, perp is in Y. Branch should deviate in Y from mid room
	var y_offset: float = absf(c_branch.y - c_mid.y)
	assert(y_offset >= 4.0, "Branch room should have lateral Y offset from its anchor room, got %f" % y_offset)

	# Region classification: Room 3 should be classified as optional or branch
	var reg3: StringName = plan.get_region(3)
	assert(reg3 == SpatialComposition.REGION_OPTIONAL or reg3 == SpatialComposition.REGION_BRANCH, "Branch should have branch or optional region, got %s" % str(reg3))

	print("  -> Passed Branch lateral offset and separation test.")

func test_non_mutating_contract_and_sealing() -> void:
	print("  Testing non-mutating contract and plan sealing...")
	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START", {"action": MissionNode.ActionType.START})
	var n1: int = graph.add_node(&"BOSS", {"action": MissionNode.ActionType.BOSS})
	graph.add_edge(n0, n1)

	var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), RoomData.RoomType.START)
	r0.mission_node_id = n0
	var r1 := RoomData.new(1, Rect2i(0, 0, 8, 8), RoomData.RoomType.BOSS)
	r1.mission_node_id = n1

	var orig_pos0 := r0.rect.position
	var orig_placed0 := r0.is_placed
	var orig_pos1 := r1.rect.position
	var orig_placed1 := r1.is_placed

	var strategy := CompositionStrategy.new()
	var plan := strategy.create_placement_plan([r0, r1], graph, Rect2i(0, 0, 60, 60))

	assert(plan.is_sealed(), "Returned plan must be sealed")
	assert(r0.rect.position == orig_pos0, "RoomData position must NOT be mutated")
	assert(r0.is_placed == orig_placed0, "RoomData is_placed must NOT be mutated")
	assert(r1.rect.position == orig_pos1, "RoomData position must NOT be mutated")
	assert(r1.is_placed == orig_placed1, "RoomData is_placed must NOT be mutated")

	print("  -> Passed non-mutating contract and sealing test.")
