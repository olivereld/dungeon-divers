class_name SpaceGrammar
extends RefCounted

## Generador de salas RoomData a partir del MissionGraph.
## Responsabilidad única: Iterar MissionGraph, crear RoomData, determinar tipo y tamaño,
## y asignar mission_node_id e is_required.
## NO coloca salas ni calcula posiciones espaciales (responsabilidad de CompositionStrategy).

const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

var _rng: RandomNumberGenerator
var rng: RandomNumberGenerator
var mission_graph: DungeonGraph
var config: SpaceGrammarConfig

func _init(p_config: SpaceGrammarConfig = null) -> void:
	_rng = RandomNumberGenerator.new()
	rng = _rng
	config = p_config if p_config != null else SpaceGrammarConfig.new()

func generate(p_mission_graph: DungeonGraph, p_config = null, random_seed: int = 0) -> Array[RoomData]:
	mission_graph = p_mission_graph
	rng = _rng

	if p_config is SpaceGrammarConfig:
		config = p_config
	elif p_config is DungeonConfig:
		if p_config.space_grammar_config != null:
			config = p_config.space_grammar_config
		else:
			config = SpaceGrammarConfig.new()
	elif config == null:
		config = SpaceGrammarConfig.new()

	if random_seed != 0:
		_rng.seed = random_seed
	elif p_config is DungeonConfig and p_config.seed != 0:
		_rng.seed = p_config.seed
	else:
		_rng.seed = 1337

	var rooms: Array[RoomData] = []
	var node_ids: Array[int] = mission_graph.get_topological_order()
	if node_ids.is_empty() and not mission_graph.get_all_node_ids().is_empty():
		push_warning("[SpaceGrammar] MISSION_GRAPH_CYCLE: Mission graph is not a valid DAG.")
		return []

	var node_to_room: Dictionary = {} # node_id -> RoomData
	var large_count: int = 0

	for i in range(node_ids.size()):
		var node_id: int = node_ids[i]
		var node_data: Dictionary = mission_graph.get_node_data(node_id)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)

		var room_type: StringName = m_node.room_type_hint
		if m_node.action == MissionNode.ActionType.BOSS:
			room_type = &"boss"
		elif m_node.action == MissionNode.ActionType.START:
			room_type = &"start"
		elif m_node.action == MissionNode.ActionType.GOAL or m_node.action == MissionNode.ActionType.PASSAGE_DOWN:
			room_type = &"goal"
		elif room_type == &"":
			room_type = &"explore"

		var remaining_rooms: int = node_ids.size() - i
		var needed_large: int = 2 - large_count
		var is_forced_large: bool = (room_type == &"boss") or (remaining_rooms <= needed_large) or (room_type == &"combat" and large_count < 2)
		var dungeon_cfg: DungeonConfig = p_config if p_config is DungeonConfig else null
		var size: Vector2i = _calculate_room_size(room_type, dungeon_cfg, is_forced_large)
		if size.x >= 11 or size.y >= 11 or (size.x * size.y >= 100):
			large_count += 1

		var room := RoomData.new(rooms.size(), Rect2i(0, 0, size.x, size.y), room_type)
		room.mission_node_id = node_id
		room.is_required = not bool(m_node.is_optional)
		
		# Blindar el mapping: verificar identidad entre MissionNode y RoomData
		assert(room.mission_node_id == node_id, "MissionNode ID %d does not match RoomData mission_node_id %d" % [node_id, room.mission_node_id])
		if m_node.action == MissionNode.ActionType.BOSS:
			assert(room.room_type == &"boss", "MissionNode BOSS action does not map to boss room_type")

		node_to_room[node_id] = room
		rooms.append(room)

	return rooms

func _calculate_room_size(type: StringName, d_config: DungeonConfig, force_large: bool = false) -> Vector2i:
	var diff: float = d_config.difficulty if d_config != null else 1.0

	if force_large or type == &"boss":
		var lw: int = _rng.randi_range(11, maxi(11, int(14 * minf(diff, 1.5))))
		var lh: int = _rng.randi_range(11, maxi(11, int(14 * minf(diff, 1.5))))
		return Vector2i(lw, lh)

	match type:
		&"start", &"goal":
			# Small (6x6 .. 7x7)
			return Vector2i(_rng.randi_range(6, 7), _rng.randi_range(6, 7))
		&"treasure":
			# Small (5x5 .. 7x7)
			return Vector2i(_rng.randi_range(5, 7), _rng.randi_range(5, 7))
		&"puzzle":
			# Small to Medium (6x6 .. 8x8)
			return Vector2i(_rng.randi_range(6, 8), _rng.randi_range(6, 8))
		&"combat", &"explore":
			var roll: float = _rng.randf()
			if roll < 0.45:
				# Small (6..7)
				return Vector2i(_rng.randi_range(6, 7), _rng.randi_range(6, 7))
			elif roll < 0.85:
				# Medium (8..10)
				return Vector2i(_rng.randi_range(8, 10), _rng.randi_range(8, 10))
			else:
				# Large (11..13)
				return Vector2i(_rng.randi_range(11, 13), _rng.randi_range(11, 13))
		_:
			return Vector2i(_rng.randi_range(6, 9), _rng.randi_range(6, 9))
