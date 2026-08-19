extends SceneTree

## Test suite para Commit 3: Selección determinista y correcta del Boss en MissionGrammar.

func _find_goal_id(graph: DungeonGraph) -> int:
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.GOAL or int(nd.get("action", -1)) == MissionNode.ActionType.PASSAGE_DOWN or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.GOAL]):
			return nid
	return -1

func _find_start_id(graph: DungeonGraph) -> int:
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.START or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.START]):
			return nid
	return -1

func _init() -> void:
	print("--- Running test_mission_grammar (1000 seeds Boss determinism) ---")
	var grammar := MissionGrammar.new()
	var config := DungeonConfig.new()
	config.mission_depth = 5
	config.boss_enabled = true

	var total_seeds: int = 1000

	for i in range(total_seeds):
		var seed_val: int = 100000 + i
		var graph1: DungeonGraph = grammar.generate(config, seed_val)

		# 1. Validar exactamente 1 BOSS
		var bosses: Array[int] = graph1.find_nodes_by_type(MissionNode.ActionType.BOSS)
		assert(bosses.size() == 1, "Seed %d: Expected exactly 1 BOSS, got %d" % [seed_val, bosses.size()])

		var boss_id: int = bosses[0]
		var goal_id: int = _find_goal_id(graph1)
		var start_id: int = _find_start_id(graph1)

		assert(start_id != -1, "Seed %d: START node must exist" % seed_val)
		assert(goal_id != -1, "Seed %d: GOAL node must exist" % seed_val)

		# 2. Validar que BOSS conecta directamente a GOAL
		assert(graph1.get_predecessors(goal_id).has(boss_id), "Seed %d: BOSS (%d) must be predecessor of GOAL (%d)" % [seed_val, boss_id, goal_id])

		# 3. Validar determinismo absoluto (misma seed -> mismo boss_node_id y mismos nodos)
		var graph2: DungeonGraph = grammar.generate(config, seed_val)
		var bosses2: Array[int] = graph2.find_nodes_by_type(MissionNode.ActionType.BOSS)
		assert(bosses2.size() == 1, "Seed %d: Repeat run must have 1 boss" % seed_val)
		assert(bosses2[0] == boss_id, "Seed %d: Boss ID must be deterministic (%d vs %d)" % [seed_val, boss_id, bosses2[0]])
		assert(graph1.get_all_node_ids() == graph2.get_all_node_ids(), "Seed %d: Node IDs must match identically" % seed_val)
		assert(graph1.get_topological_order() == graph2.get_topological_order(), "Seed %d: Topological order must match identically" % seed_val)

	print("[PASS] test_mission_grammar succeeded across %d seeds." % total_seeds)
	quit(0)
