class_name ObjectiveAssigner
extends RefCounted

## Asigna puntos de interés y objetivos de misión lógicos a las habitaciones.
## Se ejecuta estrictamente después de KeyLockPlanner sobre salas cuya alcanzabilidad está verificada.
## Garantiza que todo ObjectiveData referencia un mission_node_id y room_id válidos.
## 100% puro y determinista: no muta el CellGrid ni RoomData.

const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")

func assign_objectives(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	depth_map: Dictionary = {},
	grid: CellGrid = null,
	config: DungeonConfig = null,
	rng_seed: int = 0,
	critical_path_rooms: Array[int] = [],
	connections: Array = [],
	mission_graph: DungeonGraph = null,
	keys: Array = []
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

	var degrees: Dictionary = {}
	for c in connections:
		degrees[c.room_a_id] = degrees.get(c.room_a_id, 0) + 1
		degrees[c.room_b_id] = degrees.get(c.room_b_id, 0) + 1

	var max_depth: int = 0
	for d in depth_map.values():
		if int(d) > max_depth:
			max_depth = int(d)

	var helper_node_id = func(room: RoomData) -> int:
		if room != null and room.mission_node_id >= 0:
			return room.mission_node_id
		return room.id if room != null else 0

	# 1. START / SPAWN (Obligatorio)
	if room_map.has(start_room_id):
		var start_room: RoomData = room_map[start_room_id]
		var spawn_pos: Vector2i = start_room.get_walkable_point(grid) if grid != null else start_room.get_center()
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			_ObjectiveDataScript.ObjectiveType.START,
			start_room_id,
			spawn_pos,
			true,
			-1,
			helper_node_id.call(start_room),
			0 # progression_index
		))
		obj_id_counter += 1

	# 2. BOSS / GOAL / STAIRS_DOWN (Obligatorio)
	if room_map.has(boss_room_id):
		var boss_room: RoomData = room_map[boss_room_id]
		var boss_pos: Vector2i = boss_room.get_walkable_point(grid) if grid != null else boss_room.get_center()
		var boss_type = _ObjectiveDataScript.ObjectiveType.BOSS if (config == null or config.boss_enabled) else _ObjectiveDataScript.ObjectiveType.GOAL
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			boss_type,
			boss_room_id,
			boss_pos,
			true,
			-1,
			helper_node_id.call(boss_room),
			max_depth # progression_index
		))
		obj_id_counter += 1

	var used_rooms: Dictionary = { start_room_id: true, boss_room_id: true }

	# 3. KEY Objectives (si se han planificado llaves)
	for k in keys:
		if k != null and room_map.has(k.room_id):
			var k_room: RoomData = room_map[k.room_id]
			objectives.append(_ObjectiveDataScript.new(
				obj_id_counter,
				_ObjectiveDataScript.ObjectiveType.KEY,
				k.room_id,
				k.position,
				true,
				-1,
				helper_node_id.call(k_room),
				k.progression_index
			))
			obj_id_counter += 1
			used_rooms[k.room_id] = true

	# 4. ELITE (1-2 en el Critical Path)
	var cp_candidates: Array[RoomData] = []
	for cp_id in critical_path_rooms:
		if not used_rooms.has(cp_id) and room_map.has(cp_id):
			cp_candidates.append(room_map[cp_id])

	var elite_count: int = mini(cp_candidates.size(), 2 if cp_candidates.size() >= 3 else (1 if cp_candidates.size() >= 1 else 0))
	for e_idx in range(elite_count):
		var chosen_elite: RoomData = cp_candidates[e_idx]
		var e_pos: Vector2i = chosen_elite.get_walkable_point(grid) if grid != null else chosen_elite.get_center()
		var d_val: int = int(depth_map.get(chosen_elite.id, 1))
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			_ObjectiveDataScript.ObjectiveType.OBJECTIVE,
			chosen_elite.id,
			e_pos,
			true,
			-1,
			helper_node_id.call(chosen_elite),
			d_val
		))
		obj_id_counter += 1
		used_rooms[chosen_elite.id] = true

	# 5. TESOROS (Hojas off-path, máx 4)
	var treasure_count: int = 0
	for r in rooms:
		if used_rooms.has(r.id):
			continue
		var is_leaf: bool = degrees.get(r.id, 0) == 1
		var is_off_path: bool = not critical_path_rooms.has(r.id)
		var is_explicit_treasure: bool = (r.room_type == &"treasure" or r.room_type == &"reward")

		if (is_explicit_treasure or (is_leaf and is_off_path)) and treasure_count < 4:
			var t_pos: Vector2i = r.get_walkable_point(grid) if grid != null else r.get_center()
			var d_val: int = int(depth_map.get(r.id, 1))
			objectives.append(_ObjectiveDataScript.new(
				obj_id_counter,
				_ObjectiveDataScript.ObjectiveType.TREASURE,
				r.id,
				t_pos,
				false,
				-1,
				helper_node_id.call(r),
				d_val
			))
			obj_id_counter += 1
			used_rooms[r.id] = true
			treasure_count += 1

	# 6. PUZZLE / SHRINES (1 en mid-depth, opcional)
	var shrine_candidates: Array[RoomData] = []
	var min_mid: int = int(floor(float(max_depth) * 0.3))
	var max_mid: int = int(ceil(float(max_depth) * 0.7))

	for r in rooms:
		if used_rooms.has(r.id):
			continue
		var d: int = int(depth_map.get(r.id, 0))
		if d >= min_mid and d <= max_mid:
			shrine_candidates.append(r)

	var shrine_count: int = mini(shrine_candidates.size(), 1 if rooms.size() >= 5 else 0)
	for s_idx in range(shrine_count):
		var chosen_shrine: RoomData = shrine_candidates[s_idx]
		var s_pos: Vector2i = chosen_shrine.get_walkable_point(grid) if grid != null else chosen_shrine.get_center()
		var d_val: int = int(depth_map.get(chosen_shrine.id, 1))
		objectives.append(_ObjectiveDataScript.new(
			obj_id_counter,
			_ObjectiveDataScript.ObjectiveType.PUZZLE,
			chosen_shrine.id,
			s_pos,
			false,
			-1,
			helper_node_id.call(chosen_shrine),
			d_val
		))
		obj_id_counter += 1
		used_rooms[chosen_shrine.id] = true

	# Validar que todo objetivo tenga room_id y mission_node_id válidos
	for obj in objectives:
		assert(obj.room_id >= 0, "ObjectiveData debe tener room_id válido >= 0")
		assert(obj.mission_node_id >= 0, "ObjectiveData debe tener mission_node_id válido >= 0")

	return objectives
