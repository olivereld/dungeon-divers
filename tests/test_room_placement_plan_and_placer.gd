extends SceneTree

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomPlacer = preload("res://src/dungeon_generator/core/placement/room_placer.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")
const CompositionStrategy = preload("res://src/dungeon_generator/core/grammars/composition_strategy.gd")

func _init() -> void:
	print("--- Running test_room_placement_plan_and_placer ---")

	_test_placement_plan_contract()
	_test_room_placer_execution()
	_test_composition_strategy_immutability_and_determinism()
	_test_composition_strategy_multi_seed_integrity()

	print("[PASS] test_room_placement_plan_and_placer completed successfully.")
	quit(0)

func _test_placement_plan_contract() -> void:
	var plan := RoomPlacementPlan.new()
	assert(not plan.is_sealed(), "Plan must be mutable initially")
	assert(plan.is_empty(), "Plan must be empty initially")

	plan.add_entry(1, Vector2i(10, 20), &"region_start", 100)
	plan.add_entry(2, Vector2i(25, 20), &"region_main_path", 50)
	plan.add_entry(3, Vector2i(40, 20), &"region_boss", 90)

	assert(plan.size() == 3)
	assert(plan.has_placement(1) and plan.has_placement(2) and plan.has_placement(3))
	assert(not plan.has_placement(99))

	assert(plan.get_position(1) == Vector2i(10, 20))
	assert(plan.get_region(1) == &"region_start")
	assert(plan.get_priority(1) == 100)

	var all_ids: Array[int] = plan.get_all_room_ids()
	assert(all_ids == [1, 2, 3])

	var start_rooms: Array[int] = plan.get_rooms_in_region(&"region_start")
	assert(start_rooms == [1])

	# Seal the plan
	plan.seal()
	assert(plan.is_sealed(), "Plan must be sealed after seal() is called")

	print("  [OK] RoomPlacementPlan contract and sealing verified.")

func _test_room_placer_execution() -> void:
	var placer := RoomPlacer.new()
	var plan := RoomPlacementPlan.new()
	plan.add_entry(10, Vector2i(12, 14), &"region_start", 100)
	plan.add_entry(20, Vector2i(30, 40), &"region_boss", 90)
	plan.seal()

	var r1 := RoomData.new(10, Rect2i(0, 0, 7, 9), &"start")
	var r2 := RoomData.new(20, Rect2i(0, 0, 11, 13), &"boss")
	var rooms: Array[RoomData] = [r1, r2]

	var placed_count: int = placer.apply_plan(rooms, plan)
	assert(placed_count == 2, "Placer should apply both rooms")

	assert(r1.is_placed, "Room 10 must be marked is_placed")
	assert(r1.rect.position == Vector2i(12, 14), "Room 10 position must match plan")
	assert(r1.rect.size == Vector2i(7, 9), "Room 10 size must be preserved without alteration")
	assert(r1.region == &"region_start", "Room 10 region must match plan")

	assert(r2.is_placed, "Room 20 must be marked is_placed")
	assert(r2.rect.position == Vector2i(30, 40), "Room 20 position must match plan")
	assert(r2.rect.size == Vector2i(11, 13), "Room 20 size must be preserved without alteration")
	assert(r2.region == &"region_boss", "Room 20 region must match plan")

	assert(placer.validate_placement_integrity(rooms, 2), "Rooms should not collide")
	print("  [OK] RoomPlacer pure execution verified without altering sizes.")

func _test_composition_strategy_immutability_and_determinism() -> void:
	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START")
	var n1: int = graph.add_node(&"ROOM_1")
	var n2: int = graph.add_node(&"BOSS")
	graph.add_edge(n0, n1)
	graph.add_edge(n1, n2)

	var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), &"start")
	r0.mission_node_id = n0
	var r1 := RoomData.new(1, Rect2i(0, 0, 8, 7), &"explore")
	r1.mission_node_id = n1
	var r2 := RoomData.new(2, Rect2i(0, 0, 12, 12), &"boss")
	r2.mission_node_id = n2

	var original_rooms: Array[RoomData] = [r0, r1, r2]
	var bounds := Rect2i(2, 2, 60, 60)

	# Verify rooms are NOT placed initially
	assert(not r0.is_placed and not r1.is_placed and not r2.is_placed)
	assert(r0.rect.position == Vector2i.ZERO)

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 98765
	var strategy1 := CompositionStrategy.new(rng1)

	var plan1: RoomPlacementPlan = strategy1.create_placement_plan(original_rooms, graph, bounds)

	# CRITICAL: Verify create_placement_plan did NOT mutate original_rooms!
	assert(not r0.is_placed, "create_placement_plan must NOT mutate is_placed on inputs")
	assert(r0.rect.position == Vector2i.ZERO, "create_placement_plan must NOT mutate rect.position on inputs")
	assert(plan1.is_sealed(), "Plan must be sealed upon return")
	assert(plan1.size() == 3)

	# Check regions
	assert(plan1.get_region(0) == CompositionStrategy.REGION_START)
	assert(plan1.get_region(2) == CompositionStrategy.REGION_BOSS)

	# Determinism check with second run
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 98765
	var strategy2 := CompositionStrategy.new(rng2)
	var plan2: RoomPlacementPlan = strategy2.create_placement_plan(original_rooms, graph, bounds)

	for room_id in plan1.get_all_room_ids():
		assert(plan1.get_position(room_id) == plan2.get_position(room_id), "Positions must be 100% deterministic for seed")
		assert(plan1.get_region(room_id) == plan2.get_region(room_id), "Regions must be identical")

	print("  [OK] CompositionStrategy immutability and determinism verified.")

func _test_composition_strategy_multi_seed_integrity() -> void:
	var placer := RoomPlacer.new()
	var bounds := Rect2i(2, 2, 80, 80)

	for seed_idx in range(50):
		var seed_val: int = 1000 + seed_idx
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val

		var graph := DungeonGraph.new()
		var n0: int = graph.add_node(&"START")
		var n1: int = graph.add_node(&"ROOM_1")
		var n2: int = graph.add_node(&"ROOM_2")
		var n3: int = graph.add_node(&"ROOM_3")
		var n4: int = graph.add_node(&"BOSS")

		graph.add_edge(n0, n1)
		graph.add_edge(n1, n2)
		graph.add_edge(n2, n3)
		graph.add_edge(n3, n4)

		var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), &"start")
		r0.mission_node_id = n0
		var r1 := RoomData.new(1, Rect2i(0, 0, 7, 7), &"explore")
		r1.mission_node_id = n1
		var r2 := RoomData.new(2, Rect2i(0, 0, 5, 8), &"treasure")
		r2.mission_node_id = n2
		var r3 := RoomData.new(3, Rect2i(0, 0, 8, 6), &"puzzle")
		r3.mission_node_id = n3
		var r4 := RoomData.new(4, Rect2i(0, 0, 12, 12), &"boss")
		r4.mission_node_id = n4

		var test_rooms: Array[RoomData] = [r0, r1, r2, r3, r4]

		var strategy := CompositionStrategy.new(rng)
		var plan: RoomPlacementPlan = strategy.create_placement_plan(test_rooms, graph, bounds)
		assert(plan != null and plan.is_sealed())
		assert(plan.size() == 5)

		# Apply via RoomPlacer
		var count: int = placer.apply_plan(test_rooms, plan)
		assert(count == 5)

		# Validate integrity
		assert(placer.validate_placement_integrity(test_rooms, 2), "Seed %d: No rooms should collide with margin 2" % seed_val)
		for r in test_rooms:
			assert(bounds.encloses(r.rect), "Seed %d: Room %d rect %s must be inside bounds %s" % [seed_val, r.id, str(r.rect), str(bounds)])

	print("  [OK] CompositionStrategy + RoomPlacer verified over 50 seeds with zero collisions.")
