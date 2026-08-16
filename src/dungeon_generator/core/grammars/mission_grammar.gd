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
	elif config != null and config.use_fixed_seed:
		_rng.seed = config.seed
	else:
		_rng.randomize()

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

		# Ruleta ponderada
		var selected_rule_idx: int = _select_weighted_rule(applicable_rules)
		var selected_rule: Dictionary = applicable_rules[selected_rule_idx]
		var candidate_matches: Array = rule_matches[selected_rule_idx]
		var selected_match: Dictionary = candidate_matches[_rng.randi() % candidate_matches.size()]

		_apply_rule(graph, selected_rule, selected_match)

	return graph

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
