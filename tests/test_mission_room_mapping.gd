extends SceneTree

## Test de Commit 4: identidad MissionNode BOSS -> RoomData BOSS.
## No depende de tests/base_test.gd ni de una infraestructura externa.

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionGrammar = preload("res://src/dungeon_generator/core/grammars/mission_grammar.gd")
const SpaceGrammar = preload("res://src/dungeon_generator/core/grammars/space_grammar.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _init() -> void:
	print("--- Running test_mission_room_mapping (1000 seeds Boss identity) ---")

	var grammar := MissionGrammar.new()
	var total_seeds: int = 1000

	for i in range(total_seeds):
		var seed_val: int = 1000 + i
		var config := DungeonConfig.new()
		config.seed = seed_val
		config.mission_depth = 5
		config.boss_enabled = true

		var graph: DungeonGraph = grammar.generate(config, seed_val)
		assert(graph != null, "Seed %d: MissionGrammar returned null graph" % seed_val)

		var boss_nodes: Array[int] = []
		for node_id in graph.get_all_node_ids():
			var node_data: Dictionary = graph.get_node_data(node_id)
			if int(node_data.get("action", -1)) == MissionNode.ActionType.BOSS:
				boss_nodes.append(node_id)

		assert(
			boss_nodes.size() == 1,
			"Seed %d: Expected exactly 1 mission BOSS, got %d" % [seed_val, boss_nodes.size()]
		)

		var boss_node_id: int = boss_nodes[0]
		var boss_node_data: Dictionary = graph.get_node_data(boss_node_id)
		assert(
			int(boss_node_data.get("action", -1)) == MissionNode.ActionType.BOSS,
			"Seed %d: Boss node action is not BOSS" % seed_val
		)

		var space_grammar := SpaceGrammar.new()
		var rooms: Array[RoomData] = space_grammar.generate(graph, config, seed_val)
		assert(rooms.size() > 0, "Seed %d: SpaceGrammar returned no rooms" % seed_val)

		var boss_rooms: Array[RoomData] = []
		for room in rooms:
			if room.room_type == &"boss":
				boss_rooms.append(room)

		assert(
			boss_rooms.size() == 1,
			"Seed %d: Expected exactly 1 boss room, got %d" % [seed_val, boss_rooms.size()]
		)

		var boss_room: RoomData = boss_rooms[0]
		assert(
			boss_room.room_type == &"boss",
			"Seed %d: Boss room room_type is not 'boss'" % seed_val
		)
		assert(
			boss_room.mission_node_id == boss_node_id,
			"Seed %d: Boss room mission_node_id %d does not match mission BOSS node %d" % [
				seed_val,
				boss_room.mission_node_id,
				boss_node_id
			]
		)

	print("[PASS] test_mission_room_mapping succeeded across %d seeds." % total_seeds)
	quit(0)
