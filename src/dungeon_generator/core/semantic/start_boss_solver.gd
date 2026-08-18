class_name StartBossSolver
extends RefCounted

## Resuelve de forma determinista las salas de inicio (Start) y jefe final (Boss).
## 100% puro: no muta geometría ni depende de renderizado.

func resolve_start_and_boss(
	rooms: Array = [],
	connections: Array = [],
	grid: CellGrid = null,
	config: DungeonConfig = null,
	depth_map: Dictionary = {}
) -> Dictionary:
	# Retorna: { "start_room_id": int, "boss_room_id": int }
	if rooms.is_empty():
		return { "start_room_id": -1, "boss_room_id": -1 }

	var start_id: int = _resolve_start_room(rooms, grid, config)
	var boss_id: int = _resolve_boss_room(rooms, start_id, depth_map)

	return {
		"start_room_id": start_id,
		"boss_room_id": boss_id
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
	var max_depth: int = 0
	for d in depth_map.values():
		if int(d) > max_depth:
			max_depth = int(d)

	var min_boss_depth: int = int(ceil(float(max_depth) * 0.60))

	# 1. Buscar sala explícita de boss que cumpla el criterio de profundidad
	for r in rooms:
		if (r.room_type == &"boss" or r.room_type == &"goal") and r.id != start_id:
			var d: int = int(depth_map.get(r.id, 0))
			if d >= min_boss_depth or max_depth <= 1:
				return r.id

	# 2. Si no hay sala explícita con profundidad suficiente, buscar sala de mayor área entre las que cumplen depth >= 60% max_depth
	var best_boss_id: int = -1
	var best_score: int = -1

	for r in rooms:
		if r.id == start_id:
			continue
		var d: int = int(depth_map.get(r.id, 0))
		if d >= min_boss_depth:
			var area: int = r.rect.size.x * r.rect.size.y
			# Score compuesto: área ponderada + profundidad
			var score: int = area * 100 + d * 10 + r.id
			if score > best_score:
				best_score = score
				best_boss_id = r.id

	if best_boss_id != -1:
		return best_boss_id

	# Fallback a sala de máxima profundidad absoluta
	var max_d: int = -1
	for r in rooms:
		if r.id == start_id:
			continue
		var d: int = int(depth_map.get(r.id, -1))
		if d > max_d:
			max_d = d
			best_boss_id = r.id

	if best_boss_id != -1:
		return best_boss_id

	return start_id
