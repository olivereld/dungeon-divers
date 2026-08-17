class_name ObjectiveAssigner
extends RefCounted

## Asigna puntos de interés y objetivos de misión lógicos a las habitaciones.
## Se ejecuta estrictamente después de KeyLockPlanner sobre salas cuya alcanzabilidad está verificada.
## 100% puro y determinista: no muta el CellGrid.

const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")

func assign_objectives(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	depth_map: Dictionary = {},
	grid: CellGrid = null,
	config: DungeonConfig = null,
	rng_seed: int = 0
) -> Array:
	var objectives: Array = []
	if rooms.is_empty():
		return objectives

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var obj_id_counter: int = 1

	var room_map: Dictionary = {}
	for r in rooms:
		room_map[r.id] = r

	# 1. SPAWN (Obligatorio)
	if room_map.has(start_room_id):
		var start_room: RoomData = room_map[start_room_id]
		var spawn_pos: Vector2i = start_room.get_walkable_point(grid) if grid != null else start_room.get_center()
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			_ObjectiveDataScript.ObjectiveType.SPAWN,
			start_room_id,
			spawn_pos,
			true,
			-1
		))
		obj_id_counter += 1

	# 2. BOSS / STAIRS_DOWN (Obligatorio)
	if room_map.has(boss_room_id):
		var boss_room: RoomData = room_map[boss_room_id]
		var boss_pos: Vector2i = boss_room.get_walkable_point(grid) if grid != null else boss_room.get_center()
		var boss_type = _ObjectiveDataScript.ObjectiveType.BOSS if (config == null or config.boss_enabled) else _ObjectiveDataScript.ObjectiveType.STAIRS_DOWN
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			boss_type,
			boss_room_id,
			boss_pos,
			true,
			-1
		))
		obj_id_counter += 1

	# 3. TESOROS / OBJETIVOS OPCIONALES
	for r in rooms:
		if r.id == start_room_id or r.id == boss_room_id:
			continue
		if r.room_type == &"treasure" or r.room_type == &"reward":
			var t_pos: Vector2i = r.get_walkable_point(grid) if grid != null else r.get_center()
			objectives.append(_ObjectiveDataScript.new(
				obj_id_counter,
				_ObjectiveDataScript.ObjectiveType.TREASURE,
				r.id,
				t_pos,
				false,
				-1
			))
			obj_id_counter += 1

	# Si no había salas de tesoro explícitas y la mazmorra tiene suficientes salas, colocar 1 cofre en sala secundaria
	if objectives.size() == 2 and rooms.size() >= 5:
		var candidate_treasure_rooms: Array[RoomData] = []
		for r in rooms:
			if r.id != start_room_id and r.id != boss_room_id:
				candidate_treasure_rooms.append(r)
		if not candidate_treasure_rooms.is_empty():
			var chosen: RoomData = candidate_treasure_rooms[rng.randi_range(0, candidate_treasure_rooms.size() - 1)]
			var pos: Vector2i = chosen.get_walkable_point(grid) if grid != null else chosen.get_center()
			objectives.append(_ObjectiveDataScript.new(
				obj_id_counter,
				_ObjectiveDataScript.ObjectiveType.TREASURE,
				chosen.id,
				pos,
				false,
				-1
			))
			obj_id_counter += 1

	return objectives
