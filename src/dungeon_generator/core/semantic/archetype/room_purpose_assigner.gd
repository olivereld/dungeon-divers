class_name RoomPurposeAssigner
extends RefCounted

## Algoritmo de asignación pura y determinista de propósitos arquitectónicos a cada habitación.
## Mapea roles de gameplay ("START", "BOSS", "TREASURE", "COMBAT", "EXPLORE") a propósitos
## permitidos según el perfil de arquetipo y selecciona mediante pesos ponderados.

const _DungeonArchetypeProfileScript = preload("res://src/dungeon_generator/config/dungeon_archetype_profile.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func assign_purposes(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array, # Array[RoomData]
	objectives: Array, # Array[ObjectiveData]
	profile: _DungeonArchetypeProfileScript,
	seed_val: int
) -> Dictionary:
	var result: Dictionary = {} # room_id (int) -> RoomPurpose.Type (int)
	if profile == null or rooms.is_empty():
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Indexar objetivos por room_id
	var room_objectives: Dictionary = {}
	for obj in objectives:
		room_objectives[obj.room_id] = obj

	for room in rooms:
		var r_id: int = room.id
		var gameplay_role: String = "EXPLORE"

		if r_id == start_room_id:
			gameplay_role = "START"
		elif r_id == boss_room_id:
			gameplay_role = "BOSS"
		elif room_objectives.has(r_id):
			var obj = room_objectives[r_id]
			match obj.type:
				0: gameplay_role = "TREASURE" # ObjectiveType.TREASURE
				1: gameplay_role = "COMBAT"   # ObjectiveType.DEFEAT_ENEMIES / SURVIVAL
				2: gameplay_role = "EXPLORE"  # ObjectiveType.EXPLORATION
				_: gameplay_role = "COMBAT"
		elif room.room_type == &"combat":
			gameplay_role = "COMBAT"
		elif room.room_type == &"treasure":
			gameplay_role = "TREASURE"
		elif room.room_type == &"start":
			gameplay_role = "START"
		elif room.room_type == &"boss":
			gameplay_role = "BOSS"

		var allowed_purposes: Array = profile.get_allowed_purposes_for_gameplay(gameplay_role)
		var chosen_purpose: int = _pick_weighted_purpose(allowed_purposes, profile.purpose_weights, rng)
		result[r_id] = chosen_purpose

	return result

func _pick_weighted_purpose(allowed: Array, weights: Dictionary, rng: RandomNumberGenerator) -> int:
	if allowed.is_empty():
		return _RoomPurposeScript.Type.GENERIC
	if allowed.size() == 1:
		return int(allowed[0])

	var total_weight: float = 0.0
	for p in allowed:
		total_weight += float(weights.get(int(p), 1.0))

	if total_weight <= 0.0:
		return int(allowed[0])

	var roll: float = rng.randf() * total_weight
	var accum: float = 0.0
	for p in allowed:
		accum += float(weights.get(int(p), 1.0))
		if roll <= accum:
			return int(p)

	return int(allowed[allowed.size() - 1])
