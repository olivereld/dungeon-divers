extends RefCounted

## Test que verifica la identidad entre MissionNode BOSS y RoomData BOSS.
## Garantiza que el BOSS del MissionGraph se convierta en exactamente una RoomData Boss con el mismo mission_node_id.

const DungeonConfig = preload("res://src/dungeon_generator/core/data/dungeon_config.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionGrammar = preload("res://src/dungeon_generator/core/grammars/mission_grammar.gd")
const SpaceGrammar = preload("res://src/dungeon_generator/core/grammars/space_grammar.gd")
const MissionNode = preload("res://src/dungeon_generator/core/grammars/mission_node.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")

func _get_test_name() -> String:
	return "MissionNode to RoomData Boss Identity"

func test_mission_room_boss_mapping_1000_seeds() -> void:
	var passed: int = 0
	var failed: int = 0
	
	for seed_idx in range(1000):
		var seed_val: int = 1000 + seed_idx
		var config := DungeonConfig.new()
		config.seed = seed_val
		config.room_count = 42
		
		# Generar MissionGraph
		var grammar := MissionGrammar.new()
		var graph := DungeonGraph.new()
		var mission_result := grammar.generate(graph, config)
		
		if not mission_result:
			failed += 1
			push_error("[test_mission_room_mapping] Seed %d: MissionGrammar failed to generate graph" % seed_val)
			continue
		
		# Buscar MissionNode BOSS
		var boss_nodes: Array[int] = []
		for node_id in graph.get_all_node_ids():
			var node_data: Dictionary = graph.get_node_data(node_id)
			var m_node: MissionNode = MissionNode.from_dictionary(node_data)
			if m_node.action == MissionNode.ActionType.BOSS or m_node.room_type_hint == &"boss":
				boss_nodes.append(node_id)
		
		# Assert: exactamente 1 boss en MissionGraph
		_assert_equal(boss_nodes.size(), 1, "Seed %d: Expected exactly 1 mission boss node, got %d" % [seed_val, boss_nodes.size()])
		if boss_nodes.size() != 1:
			failed += 1
			continue
		
		# Generar SpaceGrammar (RoomData)
		var space_grammar := SpaceGrammar.new()
		var rooms: Array[RoomData] = space_grammar.generate(graph, config, seed_val)
		
		# Buscar RoomData BOSS
		var boss_rooms: Array[RoomData] = []
		for room in rooms:
			if room.room_type == &"boss":
				boss_rooms.append(room)
		
		# Assert: exactamente 1 boss en RoomData
		_assert_equal(boss_rooms.size(), 1, "Seed %d: Expected exactly 1 room boss, got %d" % [seed_val, boss_rooms.size()])
		if boss_rooms.size() != 1:
			failed += 1
			continue
		
		# Assert: room_type debe ser "boss"
		_assert_equal(boss_rooms[0].room_type, &"boss", "Seed %d: Boss room room_type is not 'boss'" % seed_val)
		
		# Assert CRÍTICO: mission_node_id del boss room debe coincidir con el nodo boss del grafo
		var expected_mission_node_id: int = boss_nodes[0]
		var actual_mission_node_id: int = boss_rooms[0].mission_node_id
		_assert_equal(actual_mission_node_id, expected_mission_node_id, 
			"Seed %d: Boss room mission_node_id %d does not match mission graph boss node %d" % [
				seed_val, actual_mission_node_id, expected_mission_node_id
			])
		
		if actual_mission_node_id == expected_mission_node_id:
			passed += 1
		else:
			failed += 1
	
	print("[test_mission_room_mapping] Completed 1000 seeds: %d PASSED, %d FAILED" % [passed, failed])
	_assert_equal(failed, 0, "test_mission_room_mapping: %d seeds failed out of 1000" % failed)

func test_boss_uniqueness_in_rooms() -> void:
	## Test adicional de unicidad: verificar que no haya más de un boss en rooms
	var seed_val: int = 352896113
	var config := DungeonConfig.new()
	config.seed = seed_val
	config.room_count = 42
	
	var grammar := MissionGrammar.new()
	var graph := DungeonGraph.new()
	grammar.generate(graph, config)
	
	var space_grammar := SpaceGrammar.new()
	var rooms: Array[RoomData] = space_grammar.generate(graph, config, seed_val)
	
	var boss_rooms: Array[RoomData] = []
	for room in rooms:
		if room.room_type == &"boss":
			boss_rooms.append(room)
	
	_assert_equal(boss_rooms.size(), 1, "Expected exactly 1 boss room, got %d" % boss_rooms.size())
