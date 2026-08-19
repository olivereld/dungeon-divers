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
