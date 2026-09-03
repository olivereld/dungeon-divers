extends SceneTree

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionGrammar = preload("res://src/dungeon_generator/core/grammars/mission_grammar.gd")
const SpaceGrammar = preload("res://src/dungeon_generator/core/grammars/space_grammar.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_mission_aware_room_placement ---")

	_test_config_defaults_and_duplication()
	_test_dungeon_graph_neighbors()
	_test_anchor_computation()
	_test_placed_neighbors_filter()
	_test_overlap_validation()
	test_score_prefers_correct_distance()
	_test_placement_order()
	test_mission_aware_determinism()
	_test_mission_aware_placement_multi_seed()
	_test_fallback_mechanism()

	print("[PASS] test_mission_aware_room_placement completed successfully.")
	quit(0)

func _test_config_defaults_and_duplication() -> void:
	var cfg := SpaceGrammarConfig.new()
	assert(not cfg.use_mission_aware_placement, "Default use_mission_aware_placement should be false")
	assert(is_equal_approx(cfg.mission_aware_preferred_distance, 12.0), "Default distance should be 12.0")
	assert(cfg.mission_aware_candidate_count == 15, "Default candidate count should be 15")
	assert(is_equal_approx(cfg.mission_aware_distance_jitter, 4.0), "Default jitter should be 4.0")

	cfg.use_mission_aware_placement = true
	cfg.mission_aware_preferred_distance = 15.0
	cfg.mission_aware_candidate_count = 20
	cfg.mission_aware_distance_jitter = 2.5

	var copy: SpaceGrammarConfig = cfg.duplicate_config()
	assert(copy.use_mission_aware_placement == true)
	assert(is_equal_approx(copy.mission_aware_preferred_distance, 15.0))
	assert(copy.mission_aware_candidate_count == 20)
	assert(is_equal_approx(copy.mission_aware_distance_jitter, 2.5))
	print("  [OK] SpaceGrammarConfig defaults and duplication verified.")

func _test_dungeon_graph_neighbors() -> void:
	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START")
	var n1: int = graph.add_node(&"ROOM_1")
	var n2: int = graph.add_node(&"ROOM_2")
	var n3: int = graph.add_node(&"ROOM_3")

	graph.add_edge(n0, n1)
	graph.add_edge(n2, n1)
	graph.add_edge(n1, n3)

	var n1_neighbors: Array[int] = graph.get_neighbors(n1)
	assert(n1_neighbors.size() == 3, "Node 1 should have 3 neighbors (predecessors n0, n2 and successor n3)")
	assert(n1_neighbors.has(n0) and n1_neighbors.has(n2) and n1_neighbors.has(n3))

	var n0_neighbors: Array[int] = graph.get_neighbors(n0)
	assert(n0_neighbors == [n1])
	print("  [OK] DungeonGraph.get_neighbors verified.")

func _test_anchor_computation() -> void:
	var sg := SpaceGrammar.new()
	var r1 := RoomData.new(0, Rect2i(10, 10, 6, 6), &"start")
	var r2 := RoomData.new(1, Rect2i(20, 20, 6, 6), &"explore")
	# Centers: r1 center = (13, 13), r2 center = (23, 23)
	var anchor: Vector2 = sg._compute_anchor([r1, r2])
	assert(anchor.is_equal_approx(Vector2(18.0, 18.0)), "Centroid of (13,13) and (23,23) must be (18,18)")
	print("  [OK] _compute_anchor verified.")

func _test_placed_neighbors_filter() -> void:
	var sg := SpaceGrammar.new()
	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START")
	var n1: int = graph.add_node(&"ROOM_1")
	var n2: int = graph.add_node(&"ROOM_2")
	graph.add_edge(n0, n1)
	graph.add_edge(n1, n2)
	sg.mission_graph = graph

	var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), &"start")
	r0.mission_node_id = n0
	r0.is_placed = true

	var r2 := RoomData.new(2, Rect2i(20, 20, 6, 6), &"explore")
	r2.mission_node_id = n2
	r2.is_placed = false

	var r1 := RoomData.new(1, Rect2i(10, 10, 6, 6), &"explore")
	r1.mission_node_id = n1
	r1.is_placed = false

	var placed: Array[RoomData] = sg._get_placed_neighbors(r1, [r0, r2])
	assert(placed.size() == 1, "Only r0 is placed and adjacent to r1")
	assert(placed[0] == r0)
	print("  [OK] _get_placed_neighbors verified.")

func _test_overlap_validation() -> void:
	var sg := SpaceGrammar.new()
	var r0 := RoomData.new(0, Rect2i(10, 10, 6, 6), &"start")
	var existing: Array[RoomData] = [r0]
	var bounds := Rect2i(0, 0, 100, 100)

	# Direct overlap with r0
	assert(sg._has_overlap(Vector2i(10, 10), Vector2i(6, 6), existing), "Identical rect should overlap")
	assert(not sg._is_position_valid(Vector2i(10, 10), Vector2i(6, 6), bounds, existing), "Direct overlap should be invalid position")

	# Overlap within margin of 2 cells (r0 end is at (16, 16), expanded(2) reaches (18, 18))
	assert(sg._has_overlap(Vector2i(17, 10), Vector2i(6, 6), existing), "Within padding margin should report overlap")
	assert(not sg._is_position_valid(Vector2i(17, 10), Vector2i(6, 6), bounds, existing), "Within padding should be invalid")

	# Clear separation (pos at (19, 10) does not intersect expanded(2) ending at (18, 18))
	assert(not sg._has_overlap(Vector2i(19, 10), Vector2i(6, 6), existing), "Sufficiently separated should not overlap")
	assert(sg._is_position_valid(Vector2i(19, 10), Vector2i(6, 6), bounds, existing), "Sufficiently separated should be valid")

	# Outside bounds
	assert(not sg._is_position_valid(Vector2i(-1, 0), Vector2i(6, 6), bounds, existing), "Out of bounds should be invalid position")
	print("  [OK] Overlap validation and position validity verified.")

func _make_test_room(pos: Vector2i, size: Vector2i) -> RoomData:
	return RoomData.new(0, Rect2i(pos, size), &"explore")

func test_score_prefers_correct_distance() -> void:
	var sg := SpaceGrammar.new()
	var anchor_room := _make_test_room(Vector2i(0, 0), Vector2i(4, 4))
	anchor_room.is_placed = true
	var room := _make_test_room(Vector2i.ZERO, Vector2i(4, 4))
	var candidate_close := Vector2i(6, 2)
	var candidate_far := Vector2i(40, 2)
	var candidate_ideal := Vector2i(14, 2)
	var score_close := sg._score_candidate(candidate_close, room, [anchor_room], [anchor_room])
	var score_far := sg._score_candidate(candidate_far, room, [anchor_room], [anchor_room])
	var score_ideal := sg._score_candidate(candidate_ideal, room, [anchor_room], [anchor_room])
	assert(score_ideal > score_close, "Ideal distance score should be higher than close candidate")
	assert(score_ideal > score_far, "Ideal distance score should be higher than far candidate")
	print("  [OK] test_score_prefers_correct_distance passed (ideal: %f > close: %f, far: %f)." % [score_ideal, score_close, score_far])

func _test_placement_order() -> void:
	var mission_grammar := MissionGrammar.new()
	var space_grammar := SpaceGrammar.new()
	var config := DungeonConfig.new()
	config.seed = 42
	config.use_mission_aware_placement = true

	var graph: DungeonGraph = mission_grammar.generate(config, 42)
	assert(graph != null)

	var topo_order: Array[int] = graph.get_topological_order()
	assert(not topo_order.is_empty())

	# Verify start node is first
	var start_data := graph.get_node_data(topo_order[0])
	assert(int(start_data.get("action", -1)) == MissionNode.ActionType.START, "Topological order first node must be START")

	# Verify each non-start node has at least one predecessor appearing before it in topo_order
	for idx in range(1, topo_order.size()):
		var node_id: int = topo_order[idx]
		var preds: Array[int] = graph.get_predecessors(node_id)
		var has_prior_pred := false
		for p in preds:
			if topo_order.find(p) < idx:
				has_prior_pred = true
				break
		assert(has_prior_pred, "Node %d must have at least one predecessor placed prior in topological order" % node_id)

	# Verify SpaceGrammar generates rooms matching this topological node order
	var rooms: Array[RoomData] = space_grammar.generate(graph, config, 42)
	assert(rooms.size() == topo_order.size(), "Room count must match topological node count")
	for idx in range(rooms.size()):
		assert(rooms[idx].mission_node_id == topo_order[idx], "Room index %d must correspond to topological node %d" % [idx, topo_order[idx]])

	print("  [OK] Placement order (topological BFS from START) verified.")

func test_mission_aware_determinism() -> void:
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	var seed := 12345
	config.use_mission_aware_placement = true
	var result_a := pipeline.generate(config, seed)
	var result_b := pipeline.generate(config, seed)
	assert(result_a != null and result_b != null, "Generation must produce results")
	assert(result_a.checksum == result_b.checksum, "Mission-aware placement no es determinista para seed %d" % seed)
	print("  [OK] test_mission_aware_determinism passed with matching checksum: %s" % result_a.checksum)

func _test_mission_aware_placement_multi_seed() -> void:
	var mission_grammar := MissionGrammar.new()
	var space_grammar := SpaceGrammar.new()
	var bounds := Rect2i(3, 3, 58, 58)

	var total_seeds: int = 100
	for i in range(total_seeds):
		var seed_val: int = 5000 + i
		var config := DungeonConfig.new()
		config.seed = seed_val
		config.use_mission_aware_placement = true
		config.mission_aware_preferred_distance = 12.0
		config.mission_aware_candidate_count = 16
		config.mission_aware_distance_jitter = 3.0

		var graph: DungeonGraph = mission_grammar.generate(config, seed_val)
		assert(graph != null)

		var rooms: Array[RoomData] = space_grammar.generate(graph, config, seed_val)
		assert(rooms.size() >= 4, "Seed %d: Should generate rooms" % seed_val)

		# Verify all rooms have is_placed == true
		for r in rooms:
			assert(r.is_placed, "Seed %d: Room %d must be marked is_placed" % [seed_val, r.id])

		# Verify start room is first
		assert(rooms[0].room_type == RoomData.RoomType.START or rooms[0].room_type == &"start")

		# Verify within grid bounds
		for r in rooms:
			assert(bounds.encloses(r.rect), "Seed %d: Room %d rect %s outside bounds %s" % [seed_val, r.id, str(r.rect), str(bounds)])

		# Verify no overlap between any pair
		for a_idx in range(rooms.size()):
			for b_idx in range(a_idx + 1, rooms.size()):
				assert(not rooms[a_idx].rect.intersects(rooms[b_idx].rect), "Seed %d: Room %d and %d must not intersect" % [seed_val, rooms[a_idx].id, rooms[b_idx].id])

	print("  [OK] Mission-aware placement verified across %d seeds without overlaps or out-of-bounds." % total_seeds)

func _test_fallback_mechanism() -> void:
	var sg := SpaceGrammar.new()
	var graph := DungeonGraph.new()
	var n0: int = graph.add_node(&"START")
	var n1: int = graph.add_node(&"ISOLATED") # Not connected to n0
	sg.mission_graph = graph
	sg.config.use_mission_aware_placement = true
	sg.config.mission_aware_candidate_count = 10

	var bounds := Rect2i(3, 3, 30, 30)
	var r0 := RoomData.new(0, Rect2i(0, 0, 6, 6), &"start")
	r0.mission_node_id = n0
	sg._place_room(r0, [], bounds)
	assert(r0.is_placed, "r0 start room must be placed")

	var r1 := RoomData.new(1, Rect2i(0, 0, 6, 6), &"explore")
	r1.mission_node_id = n1 # Disconnected
	sg._place_room(r1, [r0], bounds)

	assert(r1.is_placed, "r1 must still be placed via legacy fallback")
	assert(not r1.rect.intersects(r0.rect), "r1 and r0 must not intersect")
	print("  [OK] Fallback mechanism cleanly handles disconnected / failed placement.")
