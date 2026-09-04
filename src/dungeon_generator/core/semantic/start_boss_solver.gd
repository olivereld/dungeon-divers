class_name StartBossSolver
extends RefCounted

## Resuelve de forma determinista las salas y nodos de inicio (Start) y jefe final (Boss).
## Reutiliza formalmente la semántica de SpatialIntentBuilder para garantizar 0 divergencias
## entre la intención espacial y la semántica de gameplay.
## 100% puro: no muta geometría ni depende de renderizado.

const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")

func resolve_start_and_boss(
	rooms: Array = [],
	connections: Array = [],
	grid: CellGrid = null,
	config: DungeonConfig = null,
	depth_map: Dictionary = {},
	mission_graph: DungeonGraph = null,
	spatial_intent: SpatialIntentResult = null
) -> Dictionary:
	# 1. Si se dispone de mission_graph o spatial_intent, reutilizar la semántica canónica de SpatialIntentBuilder
	var intent_res: SpatialIntentResult = spatial_intent
	if intent_res == null and mission_graph != null:
		var builder := SpatialIntentBuilder.new()
		intent_res = builder.build(mission_graph)

	if intent_res != null and intent_res.valid:
		var s_node: int = intent_res.start_node_id
		var b_node: int = intent_res.terminal_node_id

		var mapped_start: int = -1
		var mapped_boss: int = -1

		for r in rooms:
			if r != null and "mission_node_id" in r:
				if r.mission_node_id == s_node and mapped_start == -1:
					mapped_start = r.id
				if r.mission_node_id == b_node and mapped_boss == -1:
					mapped_boss = r.id

		if mapped_start != -1 and mapped_boss != -1:
			return {
				"start_room_id": mapped_start,
				"boss_room_id": mapped_boss,
				"start_node_id": s_node,
				"boss_node_id": b_node
			}
		elif mapped_start != -1:
			# Si boss no tuviera sala asignada directamente, resolver por tipo o profundidad
			var resolved_boss := _resolve_boss_room(rooms, mapped_start, depth_map)
			return {
				"start_room_id": mapped_start,
				"boss_room_id": resolved_boss,
				"start_node_id": s_node,
				"boss_node_id": b_node
			}

	# 2. Fallback determinista sobre habitaciones cuando no se pasa un grafo de misión
	if rooms.is_empty():
		return {
			"start_room_id": -1,
			"boss_room_id": -1,
			"start_node_id": -1,
			"boss_node_id": -1
		}

	var start_id: int = _resolve_start_room(rooms, grid, config)
	var boss_id: int = _resolve_boss_room(rooms, start_id, depth_map)

	return {
		"start_room_id": start_id,
		"boss_room_id": boss_id,
		"start_node_id": -1,
		"boss_node_id": -1
	}

func _resolve_start_room(rooms: Array = [], grid: CellGrid = null, config: DungeonConfig = null) -> int:
	# 1. start_room_hint si está definido en config o metadata
	if config != null and "start_room_hint" in config and config.get("start_room_hint") >= 0:
		var hint: int = int(config.get("start_room_hint"))
		for r in rooms:
			if r.id == hint:
				return r.id

	# 2. room_type == &"start"
	for r in rooms:
		if r.room_type == &"start":
			return r.id

	# 3. Fallback determinista: menor coordenada lexicográfica (y * 100000 + x) del punto transitable
	var best_id: int = -1
	var min_coord_score: int = 2147483647

	for r in rooms:
		var p: Vector2i = r.get_walkable_point(grid) if grid != null else r.get_center()
		var score: int = p.y * 100000 + p.x
		if score < min_coord_score:
			min_coord_score = score
			best_id = r.id
		elif score == min_coord_score and (best_id == -1 or r.id < best_id):
			best_id = r.id

	return best_id if best_id != -1 else rooms[0].id

func _resolve_boss_room(rooms: Array = [], start_id: int = -1, depth_map: Dictionary = {}) -> int:
	# 1. Búsqueda por identidad directa: sala de tipo boss
	for r in rooms:
		if r.room_type == &"boss":
			return r.id

	# 2. Fallback por máxima profundidad si no existe sala con tipo boss
	var max_d: int = -1
	var best_boss_id: int = -1
	for r in rooms:
		if r.id == start_id:
			continue
		var d: int = int(depth_map.get(r.id, -1))
		if d > max_d:
			max_d = d
			best_boss_id = r.id

	return best_boss_id if best_boss_id != -1 else start_id
