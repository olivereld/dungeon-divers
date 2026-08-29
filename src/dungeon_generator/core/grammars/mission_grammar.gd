class_name MissionGrammar
extends RefCounted

## Generador de grafos de misiones basado en reescritura de reglas (Dormans).
## Produce un grafo abstracto de acciones (START -> ... -> GOAL) garantizando la lógica jugable.

var _rng: RandomNumberGenerator
var _key_counter: int = 0

func _init() -> void:
	_rng = RandomNumberGenerator.new()

func generate(config: DungeonConfig, random_seed: int = 0) -> DungeonGraph:
	if random_seed != 0:
		_rng.seed = random_seed
	elif config != null and config.seed != 0:
		_rng.seed = config.seed
	else:
		_rng.seed = 1337

	_key_counter = 0
	var graph := DungeonGraph.new()

	# 1. Grafo semilla: START -> GOAL
	var start_data := MissionNode.new(MissionNode.ActionType.START).to_dictionary()
	var goal_data := MissionNode.new(MissionNode.ActionType.GOAL).to_dictionary()

	var start_id: int = graph.add_node(
		StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.START]),
		start_data
	)
	var goal_id: int = graph.add_node(
		StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.GOAL]),
		goal_data
	)
	graph.add_edge(start_id, goal_id)

	var target_depth: int = 5
	var max_iterations: int = 25
	if config != null:
		target_depth = config.mission_depth
		max_iterations = config.max_grammar_iterations

	var rules: Array[Dictionary] = GrammarRules.get_mission_rules(config)

	# 2. Iteraciones de reescritura
	for _i in range(max_iterations):
		if graph.get_node_count() >= target_depth + 2: # +2 por START y GOAL
			break

		var applicable_rules: Array[Dictionary] = []
		var rule_matches: Array[Array] = []

		for rule in rules:
			var matches: Array[Dictionary] = graph.find_matching_subgraph(
				rule["lhs_nodes"],
				rule["lhs_edges"]
			)
			if not matches.is_empty():
				applicable_rules.append(rule)
				rule_matches.append(matches)

		if applicable_rules.is_empty():
			break

		# Filtrar reglas que duplican BOSS si ya existe uno (Fase 11)
		var has_boss: bool = _graph_has_boss(graph)
		var valid_rules: Array[Dictionary] = []
		var valid_matches: Array[Array] = []
		for r_idx in range(applicable_rules.size()):
			var r: Dictionary = applicable_rules[r_idx]
			if r.get("name", &"") == &"boss_finisher" and has_boss:
				continue
			valid_rules.append(r)
			valid_matches.append(rule_matches[r_idx])

		if valid_rules.is_empty():
			break

		# Ruleta ponderada
		var selected_rule_idx: int = _select_weighted_rule(valid_rules)
		var selected_rule: Dictionary = valid_rules[selected_rule_idx]
		var candidate_matches: Array = valid_matches[selected_rule_idx]
		var selected_match: Dictionary = candidate_matches[_rng.randi() % candidate_matches.size()]

		_apply_rule(graph, selected_rule, selected_match)

	# Garantizar exactamente 1 BOSS si boss_enabled está activo (Fase 11)
	if config == null or config.boss_enabled:
		_ensure_single_boss(graph)
		_validate_mission_graph_invariants(graph)

	return graph

func _find_start_id(graph: DungeonGraph) -> int:
	var matches: Array[int] = []
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.START or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.START]) or StringName(nd.get("room_type_hint", &"")) == &"start":
			matches.append(nid)
	return matches[0] if matches.size() == 1 else -1

func _find_goal_id(graph: DungeonGraph) -> int:
	var matches: Array[int] = []
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.GOAL or int(nd.get("action", -1)) == MissionNode.ActionType.PASSAGE_DOWN or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.GOAL]) or StringName(nd.get("room_type_hint", &"")) == &"goal":
			matches.append(nid)
	return matches[0] if matches.size() == 1 else -1

func _compute_depths_from_start(graph: DungeonGraph, start_id: int) -> Dictionary:
	var depths: Dictionary = {}
	if start_id == -1 or not graph.has_node(start_id):
		return depths
	depths[start_id] = 0
	var queue: Array[int] = [start_id]
	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var d: int = depths[curr]
		for succ in graph.get_successors(curr):
			if not depths.has(succ):
				depths[succ] = d + 1
				queue.append(succ)
	return depths

func _select_boss_candidate(graph: DungeonGraph, goal_id: int, start_id: int, depths: Dictionary) -> int:
	if goal_id == -1:
		return -1
	var preds: Array[int] = graph.get_predecessors(goal_id)
	var best_candidate: int = -1
	var max_depth: int = -1

	for cand in preds:
		if cand == start_id or cand == goal_id:
			continue
		if depths.has(cand):
			var d: int = depths[cand]
			if d > max_depth:
				max_depth = d
				best_candidate = cand
			elif d == max_depth:
				if best_candidate == -1 or cand < best_candidate:
					best_candidate = cand
	return best_candidate

func _graph_has_boss(graph: DungeonGraph) -> bool:
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.BOSS or StringName(nd.get("room_type_hint", &"")) == &"boss" or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.BOSS]):
			return true
	return false

func _ensure_single_boss(graph: DungeonGraph) -> void:
	var start_id: int = _find_start_id(graph)
	var goal_id: int = _find_goal_id(graph)
	if goal_id == -1:
		return

	var depths: Dictionary = _compute_depths_from_start(graph, start_id)
	var boss_node_id: int = _select_boss_candidate(graph, goal_id, start_id, depths)

	if boss_node_id == -1:
		# Si no hay nodo intermedio antes de GOAL, insertar explícitamente un nodo BOSS
		var chosen_pred: int = start_id
		var preds: Array[int] = graph.get_predecessors(goal_id)
		if not preds.is_empty():
			chosen_pred = preds[0]

		graph.remove_edge(chosen_pred, goal_id)
		var b_node := MissionNode.new(MissionNode.ActionType.BOSS)
		b_node.room_type_hint = &"boss"
		b_node.difficulty_weight = 2.0
		boss_node_id = graph.add_node(
			StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.BOSS]),
			b_node.to_dictionary()
		)
		graph.add_edge(chosen_pred, boss_node_id)
		graph.add_edge(boss_node_id, goal_id)

	# Obtener todos los nodos que actualmente están marcados como BOSS
	var all_node_ids: Array[int] = graph.get_all_node_ids()
	for nid in all_node_ids:
		if nid == start_id or nid == goal_id:
			continue
		var nd: Dictionary = graph.get_node_data(nid)
		var is_boss: bool = (int(nd.get("action", -1)) == MissionNode.ActionType.BOSS or StringName(nd.get("room_type_hint", &"")) == &"boss" or graph.get_node_type(nid) == StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.BOSS]))
		if is_boss and nid != boss_node_id:
			# Convertir los demás BOSS a COMBAT
			graph.set_node_data(nid, "action", MissionNode.ActionType.COMBAT)
			graph.set_node_data(nid, "room_type_hint", &"combat")
			graph.set_node_type(nid, StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.COMBAT]))

	# Asignar exactamente el boss seleccionado si no es start ni goal
	if boss_node_id != start_id and boss_node_id != goal_id:
		graph.set_node_data(boss_node_id, "action", MissionNode.ActionType.BOSS)
		graph.set_node_data(boss_node_id, "room_type_hint", &"boss")
		graph.set_node_type(boss_node_id, StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.BOSS]))

func _validate_mission_graph_invariants(graph: DungeonGraph) -> bool:
	var start_id: int = _find_start_id(graph)
	var goal_id: int = _find_goal_id(graph)
	if start_id == -1 or goal_id == -1:
		push_warning("[MissionGrammar] Invariant failed: START or GOAL count != 1")
		return false

	var boss_count: int = 0
	var boss_id: int = -1
	for nid in graph.get_all_node_ids():
		var nd: Dictionary = graph.get_node_data(nid)
		if int(nd.get("action", -1)) == MissionNode.ActionType.BOSS or StringName(nd.get("room_type_hint", &"")) == &"boss":
			boss_count += 1
			boss_id = nid

	if boss_count != 1:
		push_warning("[MissionGrammar] Invariant failed: Expected exactly 1 BOSS, got %d" % boss_count)
		return false

	if not graph.has_edge(boss_id, goal_id):
		push_warning("[MissionGrammar] Invariant failed: Edge BOSS (%d) -> GOAL (%d) must exist directly" % [boss_id, goal_id])
		return false

	var depths: Dictionary = _compute_depths_from_start(graph, start_id)
	var expected_boss_id: int = _select_boss_candidate(graph, goal_id, start_id, depths)
	if boss_id != expected_boss_id:
		push_warning("[MissionGrammar] Invariant failed: BOSS (%d) does not match max depth candidate (%d)" % [boss_id, expected_boss_id])
		return false

	return true

func _select_weighted_rule(rules: Array[Dictionary]) -> int:
	var total_weight: float = 0.0
	for r in rules:
		total_weight += float(r.get("weight", 1.0))

	var roll: float = _rng.randf_range(0.0, total_weight)
	var accum: float = 0.0
	for i in range(rules.size()):
		accum += float(rules[i].get("weight", 1.0))
		if roll <= accum:
			return i
	return rules.size() - 1

func _apply_rule(graph: DungeonGraph, rule: Dictionary, match_dict: Dictionary) -> void:
	var rule_type: String = String(rule.get("type", ""))

	match rule_type:
		"insert_between":
			var from_id: int = int(match_dict[0])
			var to_id: int = int(match_dict[1])
			graph.remove_edge(from_id, to_id)

			var insert_nodes_defs: Array = rule["insert_nodes"]
			var prev_id: int = from_id
			for node_def in insert_nodes_defs:
				var m_node := MissionNode.new(node_def["action"] as MissionNode.ActionType)
				m_node.room_type_hint = StringName(node_def.get("room_type_hint", &"explore"))
				m_node.difficulty_weight = float(node_def.get("difficulty_weight", 1.0))

				var new_id: int = graph.add_node(
					StringName(MissionNode.ActionType.keys()[m_node.action]),
					m_node.to_dictionary()
				)
				graph.add_edge(prev_id, new_id)
				prev_id = new_id
			graph.add_edge(prev_id, to_id)

		"lock_and_key":
			var from_id: int = int(match_dict[0])
			var to_id: int = int(match_dict[1])
			graph.remove_edge(from_id, to_id)

			_key_counter += 1
			var key_name := StringName("key_%d" % _key_counter)

			# Nodo FIND_KEY
			var key_node := MissionNode.new(MissionNode.ActionType.FIND_KEY)
			key_node.grants_items.append(key_name)
			key_node.room_type_hint = &"treasure"
			var key_id: int = graph.add_node(
				StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.FIND_KEY]),
				key_node.to_dictionary()
			)

			# Nodo UNLOCK
			var lock_node := MissionNode.new(MissionNode.ActionType.UNLOCK)
			lock_node.required_items.append(key_name)
			lock_node.room_type_hint = &"puzzle"
			var lock_id: int = graph.add_node(
				StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.UNLOCK]),
				lock_node.to_dictionary()
			)

			graph.add_edge(from_id, key_id)
			graph.add_edge(key_id, lock_id)
			graph.add_edge(lock_id, to_id)

		"prepend_node":
			var target_id: int = int(match_dict[0])
			var preds: Array[int] = graph.get_predecessors(target_id)
			if preds.is_empty():
				return

			var new_def: Dictionary = rule["new_node"]
			var m_node := MissionNode.new(new_def["action"] as MissionNode.ActionType)
			m_node.room_type_hint = StringName(new_def.get("room_type_hint", &"combat"))

			var new_id: int = graph.add_node(
				StringName(MissionNode.ActionType.keys()[m_node.action]),
				m_node.to_dictionary()
			)

			var chosen_pred: int = preds[_rng.randi() % preds.size()]
			graph.remove_edge(chosen_pred, target_id)
			graph.add_edge(chosen_pred, new_id)
			graph.add_edge(new_id, target_id)

		"add_branch":
			var from_id: int = int(match_dict[0])
			var to_id: int = int(match_dict[1])

			var branch_def: Dictionary = rule["branch_node"]
			var m_node := MissionNode.new(branch_def["action"] as MissionNode.ActionType)
			m_node.is_optional = true
			m_node.room_type_hint = StringName(branch_def.get("room_type_hint", &"treasure"))

			var branch_id: int = graph.add_node(
				StringName(MissionNode.ActionType.keys()[m_node.action]),
				m_node.to_dictionary()
			)

			graph.add_edge(from_id, branch_id)
			graph.add_edge(branch_id, to_id)
