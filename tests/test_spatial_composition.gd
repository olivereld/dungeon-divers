extends SceneTree

const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialCompositionBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_composition_builder.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_spatial_composition ---")

	test_spatial_composition_data_and_immutability()
	test_spatial_composition_builder_main_path_monotonicity()
	test_spatial_composition_builder_branch_anchors()
	test_spatial_composition_builder_determinism()
	test_spatial_composition_builder_direction_config()
	test_spatial_composition_builder_bounds_and_density()

	print("[PASS] All SpatialComposition tests passed successfully!")
	quit(0)

func test_spatial_composition_data_and_immutability() -> void:
	print("  Testing SpatialComposition data API and immutability...")
	var comp := SpatialComposition.new()

	assert(not comp.is_sealed(), "New composition must start unsealed.")

	comp.set_progression_direction(Vector2(1, 0))
	comp.set_main_path_node(1, 0.0, Vector2(10, 10))
	comp.set_main_path_node(2, 0.5, Vector2(25, 10))
	comp.set_main_path_node(3, 1.0, Vector2(40, 10))
	comp.set_node_region(1, SpatialComposition.REGION_START)
	comp.set_node_region(2, SpatialComposition.REGION_MID)
	comp.set_node_region(3, SpatialComposition.REGION_BOSS)
	comp.set_node_density(1, 1.0)
	comp.set_node_density(2, 1.2)
	comp.set_node_density(3, 1.5)

	# Branch node anchoring to main path node 2
	comp.set_branch_node(4, 2, 0.6, Vector2(25, 25))
	comp.set_node_region(4, SpatialComposition.REGION_BRANCH)
	comp.set_node_density(4, 0.8)

	# Query verification before seal
	assert(comp.progression_direction == Vector2(1, 0), "Direction should match")
	assert(comp.get_main_path_factor(1) == 0.0, "Node 1 factor should be 0.0")
	assert(comp.get_main_path_factor(2) == 0.5, "Node 2 factor should be 0.5")
	assert(comp.get_main_path_factor(3) == 1.0, "Node 3 factor should be 1.0")
	assert(comp.get_main_path_factor(4) == -1.0, "Node 4 (branch) factor should be -1.0 on main path")
	assert(comp.get_anchor_target(2) == Vector2(25, 10), "Node 2 anchor target should match")
	assert(comp.get_branch_anchor(4) == 2, "Node 4 branch anchor must be main path node 2")
	assert(comp.get_branch_factor(4) == 0.6, "Node 4 branch factor should be 0.6")
	assert(comp.get_density(3) == 1.5, "Node 3 density should match")
	assert(comp.get_region(1) == SpatialComposition.REGION_START, "Node 1 region should be REGION_START")
	assert(comp.get_region(4) == SpatialComposition.REGION_BRANCH, "Node 4 region should be REGION_BRANCH")
	assert(comp.is_main_path(2), "Node 2 is on main path")
	assert(not comp.is_main_path(4), "Node 4 is not on main path")
	assert(comp.has_node(4), "Node 4 is registered")

	# Seal
	comp.seal()
	assert(comp.is_sealed(), "Composition must report sealed.")

	# After seal, attempt mutation: should not corrupt values
	comp.set_progression_direction(Vector2(0, 1))
	assert(comp.progression_direction == Vector2(1, 0), "Direction must be immutable after seal.")

	comp.set_main_path_node(1, 0.99, Vector2(99, 99))
	assert(comp.get_main_path_factor(1) == 0.0, "Main path factor must be immutable after seal.")
	assert(comp.get_anchor_target(1) == Vector2(10, 10), "Anchor target must be immutable after seal.")

	comp.set_node_density(1, 99.0)
	assert(comp.get_density(1) == 1.0, "Density must be immutable after seal.")

	print("  -> Passed SpatialComposition data and immutability test.")

func test_spatial_composition_builder_main_path_monotonicity() -> void:
	print("  Testing SpatialCompositionBuilder main path monotonicity...")
	var graph := _build_sample_mission_graph()

	var builder := SpatialCompositionBuilder.new()
	var bounds := Rect2i(0, 0, 60, 60)
	var config := DungeonConfig.new()
	config.seed = 12345
	config.preferred_progression_direction = Vector2(1, 0)

	var comp: SpatialComposition = builder.build(graph, null, config, bounds)

	assert(comp != null, "Composition must not be null")
	assert(comp.is_sealed(), "Returned composition must be sealed")
	assert(comp.progression_direction == Vector2(1, 0), "Configured direction should be respected")

	var main_ids := comp.main_path_node_ids
	assert(main_ids.size() >= 3, "Main path should have at least 3 nodes")

	# Rule: START = 0.0, Terminal = 1.0
	var start_id: int = main_ids[0]
	var term_id: int = main_ids[main_ids.size() - 1]
	assert(comp.get_main_path_factor(start_id) == 0.0, "START factor must be strictly 0.0")
	assert(comp.get_main_path_factor(term_id) == 1.0, "Terminal factor must be strictly 1.0")
	assert(comp.get_region(start_id) == SpatialComposition.REGION_START, "START region must be REGION_START")
	assert(comp.get_region(term_id) == SpatialComposition.REGION_BOSS, "Terminal region must be REGION_BOSS")

	# Rule: Main path is strictly monotonic
	var prev_factor: float = -0.0001
	for id in main_ids:
		var factor: float = comp.get_main_path_factor(id)
		assert(factor >= prev_factor, "Main path factors must be monotonically non-decreasing: %f >= %f" % [factor, prev_factor])
		assert(factor >= 0.0 and factor <= 1.0, "Factors must be clamped between 0 and 1")
		prev_factor = factor

	print("  -> Passed main path monotonicity test.")

func test_spatial_composition_builder_branch_anchors() -> void:
	print("  Testing SpatialCompositionBuilder branch anchor rules...")
	var graph := _build_sample_mission_graph()

	var builder := SpatialCompositionBuilder.new()
	var bounds := Rect2i(0, 0, 80, 80)
	var config := DungeonConfig.new()
	config.seed = 54321

	var comp: SpatialComposition = builder.build(graph, null, config, bounds)
	var main_ids := comp.main_path_node_ids

	# Check all registered nodes
	var all_ids := comp.get_all_node_ids()
	assert(all_ids.size() == graph.get_node_count(), "All graph nodes should be registered")

	var branch_count: int = 0
	for id in all_ids:
		if not comp.is_main_path(id):
			branch_count += 1
			var anchor_id: int = comp.get_branch_anchor(id)
			assert(anchor_id != -1, "Branch node %d must have an anchor" % id)
			assert(main_ids.has(anchor_id), "Branch anchor %d must be in main_path_node_ids (branches inherit main anchor, cannot be main anchors)" % anchor_id)
			assert(anchor_id != id, "Branch node %d cannot anchor to itself" % id)

			# Ensure region is branch or optional
			var reg := comp.get_region(id)
			assert(reg == SpatialComposition.REGION_BRANCH or reg == SpatialComposition.REGION_OPTIONAL, "Branch region should be branch or optional")

	assert(branch_count >= 2, "Sample graph should have at least 2 branch nodes")
	print("  -> Passed branch anchor inheritance test.")

func test_spatial_composition_builder_determinism() -> void:
	print("  Testing SpatialCompositionBuilder determinism...")
	var graph := _build_sample_mission_graph()
	var bounds := Rect2i(0, 0, 70, 70)

	var config1 := DungeonConfig.new()
	config1.seed = 99999
	var comp1 := SpatialCompositionBuilder.new().build(graph, null, config1, bounds)

	var config2 := DungeonConfig.new()
	config2.seed = 99999
	var comp2 := SpatialCompositionBuilder.new().build(graph, null, config2, bounds)

	assert(comp1.progression_direction == comp2.progression_direction, "Identical seeds must yield identical progression directions")
	assert(comp1.main_path_node_ids == comp2.main_path_node_ids, "Identical seeds must yield identical main path nodes")

	for id in comp1.get_all_node_ids():
		assert(comp1.get_main_path_factor(id) == comp2.get_main_path_factor(id), "Factors must match for node %d" % id)
		assert(comp1.get_anchor_target(id) == comp2.get_anchor_target(id), "Anchor targets must match for node %d" % id)
		assert(comp1.get_branch_anchor(id) == comp2.get_branch_anchor(id), "Branch anchors must match for node %d" % id)
		assert(comp1.get_density(id) == comp2.get_density(id), "Density must match for node %d" % id)
		assert(comp1.get_region(id) == comp2.get_region(id), "Region must match for node %d" % id)

	print("  -> Passed determinism test.")

func test_spatial_composition_builder_direction_config() -> void:
	print("  Testing SpatialCompositionBuilder progression direction overrides...")
	var graph := _build_sample_mission_graph()
	var bounds := Rect2i(0, 0, 64, 64)

	var test_dirs: Array[Vector2] = [
		Vector2(0, 1),
		Vector2(-1, 0),
		Vector2(0, -1),
		Vector2(1, 1).normalized()
	]

	for dir in test_dirs:
		var config := DungeonConfig.new()
		config.preferred_progression_direction = dir
		var comp := SpatialCompositionBuilder.new().build(graph, null, config, bounds)
		var diff: float = (comp.progression_direction - dir).length()
		assert(diff < 0.001, "Composition progression direction should match configured direction (%s vs %s)" % [str(comp.progression_direction), str(dir)])

	print("  -> Passed direction configuration test.")

func test_spatial_composition_builder_bounds_and_density() -> void:
	print("  Testing SpatialCompositionBuilder bounds and density assignment...")
	var graph := _build_sample_mission_graph()
	var bounds := Rect2i(10, 10, 80, 80)

	var config := DungeonConfig.new()
	config.seed = 777
	var comp := SpatialCompositionBuilder.new().build(graph, null, config, bounds)

	for id in comp.get_all_node_ids():
		var target: Vector2 = comp.get_anchor_target(id)
		# Anchor targets should fall within or reasonably near the bounds
		assert(target.x >= bounds.position.x - 10 and target.x <= bounds.end.x + 10, "Target X %f should be near bounds %s" % [target.x, str(bounds)])
		assert(target.y >= bounds.position.y - 10 and target.y <= bounds.end.y + 10, "Target Y %f should be near bounds %s" % [target.y, str(bounds)])

		var density: float = comp.get_density(id)
		assert(density >= 0.5 and density <= 2.5, "Density must be in valid range [0.5, 2.5], got %f" % density)

	print("  -> Passed bounds and density test.")

## Construye un MissionGraph de prueba con START, ruta principal, BOSS y 2 ramas laterales.
func _build_sample_mission_graph() -> DungeonGraph:
	var graph := DungeonGraph.new()

	# Main Path: 1 (START) -> 2 (EXPLORE) -> 3 (FIND_KEY) -> 4 (UNLOCK) -> 5 (BOSS)
	var n_start: int = graph.add_node(&"START", {
		"action": MissionNode.ActionType.START,
		"label": "Entrance"
	})
	var n_mid1: int = graph.add_node(&"EXPLORE", {
		"action": MissionNode.ActionType.EXPLORE,
		"label": "Hallway"
	})
	var n_key: int = graph.add_node(&"FIND_KEY", {
		"action": MissionNode.ActionType.FIND_KEY,
		"label": "Boss Key"
	})
	var n_lock: int = graph.add_node(&"UNLOCK", {
		"action": MissionNode.ActionType.UNLOCK,
		"label": "Boss Gate"
	})
	var n_boss: int = graph.add_node(&"BOSS", {
		"action": MissionNode.ActionType.BOSS,
		"label": "Dungeon Boss"
	})

	graph.add_edge(n_start, n_mid1)
	graph.add_edge(n_mid1, n_key)
	graph.add_edge(n_key, n_lock)
	graph.add_edge(n_lock, n_boss)

	# Side Branch 1: n_mid1 -> n_treasure (TREASURE, optional)
	var n_treasure: int = graph.add_node(&"TREASURE", {
		"action": MissionNode.ActionType.TREASURE,
		"is_optional": true,
		"label": "Secret Chest"
	})
	graph.add_edge(n_mid1, n_treasure)

	# Side Branch 2: n_mid1 -> n_side1 -> n_side2 (multi-step branch off n_mid1)
	var n_side1: int = graph.add_node(&"PUZZLE", {
		"action": MissionNode.ActionType.PUZZLE,
		"is_optional": true,
		"label": "Puzzle Room"
	})
	var n_side2: int = graph.add_node(&"COMBAT", {
		"action": MissionNode.ActionType.COMBAT,
		"is_optional": true,
		"label": "Bonus Combat"
	})
	graph.add_edge(n_mid1, n_side1)
	graph.add_edge(n_side1, n_side2)

	return graph
