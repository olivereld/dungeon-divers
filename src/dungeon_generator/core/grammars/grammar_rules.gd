class_name GrammarRules
extends RefCounted

## Catálogo de reglas de reescritura para gramática de misiones y espacial.

static func get_mission_rules(config: DungeonConfig = null) -> Array[Dictionary]:
	var lock_freq: float = 0.35
	var opt_freq: float = 0.25
	var boss_on: bool = true

	if config != null:
		lock_freq = config.lock_key_frequency
		opt_freq = config.optional_branch_chance
		boss_on = config.boss_enabled

	var rules: Array[Dictionary] = [
		{
			"name": &"linear_explore",
			"weight": 1.0,
			"lhs_nodes": [
				{"id": 0, "match_any": true},
				{"id": 1, "match_any": true}
			],
			"lhs_edges": [
				{"from": 0, "to": 1}
			],
			"type": "insert_between",
			"insert_nodes": [
				{
					"action": MissionNode.ActionType.EXPLORE,
					"room_type_hint": &"explore"
				}
			]
		},
		{
			"name": &"lock_and_key",
			"weight": lock_freq,
			"lhs_nodes": [
				{"id": 0, "match_any": true},
				{"id": 1, "match_any": true}
			],
			"lhs_edges": [
				{"from": 0, "to": 1}
			],
			"type": "lock_and_key",
			"key_action": MissionNode.ActionType.FIND_KEY,
			"lock_action": MissionNode.ActionType.UNLOCK
		},
		{
			"name": &"combat_gate",
			"weight": 0.6,
			"lhs_nodes": [
				{"id": 0, "type": StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.EXPLORE]), "match_any": false}
			],
			"lhs_edges": [],
			"type": "prepend_node",
			"new_node": {
				"action": MissionNode.ActionType.COMBAT,
				"room_type_hint": &"combat"
			}
		},
		{
			"name": &"branch_optional_treasure",
			"weight": opt_freq,
			"lhs_nodes": [
				{"id": 0, "match_any": true},
				{"id": 1, "match_any": true}
			],
			"lhs_edges": [
				{"from": 0, "to": 1}
			],
			"type": "add_branch",
			"branch_node": {
				"action": MissionNode.ActionType.TREASURE,
				"is_optional": true,
				"room_type_hint": &"treasure"
			}
		},
		{
			"name": &"puzzle_challenge",
			"weight": 0.4,
			"lhs_nodes": [
				{"id": 0, "type": StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.EXPLORE]), "match_any": false}
			],
			"lhs_edges": [],
			"type": "prepend_node",
			"new_node": {
				"action": MissionNode.ActionType.PUZZLE,
				"room_type_hint": &"puzzle"
			}
		}
	]

	if boss_on:
		rules.append({
			"name": &"boss_finisher",
			"weight": 0.5,
			"lhs_nodes": [
				{"id": 0, "match_any": true},
				{"id": 1, "type": StringName(MissionNode.ActionType.keys()[MissionNode.ActionType.GOAL]), "match_any": false}
			],
			"lhs_edges": [
				{"from": 0, "to": 1}
			],
			"type": "insert_between",
			"insert_nodes": [
				{
					"action": MissionNode.ActionType.BOSS,
					"room_type_hint": &"boss",
					"difficulty_weight": 2.0
				}
			]
		})

	return rules
