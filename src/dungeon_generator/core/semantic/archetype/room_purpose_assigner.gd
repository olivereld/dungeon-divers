class_name RoomPurposeAssigner
extends RefCounted

## Algoritmo de asignación pura y determinista de propósitos arquitectónicos a cada habitación.
## Combina mapeo de roles de gameplay ("START", "BOSS", "TREASURE", "COMBAT") con la distribución
## macro (room_purpose_distribution) para salas de exploración y reglas de restricción (room_rules).

const _DungeonArchetypeProfileScript = preload("res://src/dungeon_generator/config/dungeon_archetype_profile.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ProfileArchetypeScript = preload("res://src/dungeon_generator/profiles/profile_archetype.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")

func assign_purposes(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array, # Array[RoomData]
	objectives: Array, # Array[ObjectiveData]
	profile, # ProfileBundle, ProfileArchetype or DungeonArchetypeProfile
	seed_val: int
) -> Dictionary:
	var result: Dictionary = {} # room_id (int) -> RoomPurpose.Type (int)
	if profile == null or rooms.is_empty():
		return result

	var arch_profile: _ProfileArchetypeScript = null
	var legacy_profile: _DungeonArchetypeProfileScript = null

	if profile is _ProfileBundleScript:
		arch_profile = profile.archetype
	elif profile is _ProfileArchetypeScript:
		arch_profile = profile
	elif profile is _DungeonArchetypeProfileScript:
		legacy_profile = profile

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Indexar objetivos por room_id
	var room_objectives: Dictionary = {}
	for obj in objectives:
		room_objectives[obj.room_id] = obj

	# Extraer reglas de arquetipo si existen
	var max_consecutive: int = 2
	var rare_purposes: Array[int] = []
	var guaranteed_purposes: Array[int] = []
	var distribution_weights: Dictionary = {} # int (RoomPurpose.Type) -> float

	if arch_profile != null:
		if arch_profile.room_rules != null:
			max_consecutive = arch_profile.room_rules.max_same_purpose_consecutive
			for r in arch_profile.room_rules.rare:
				rare_purposes.append(int(_RoomPurposeScript.from_name(str(r))))
			for g in arch_profile.room_rules.guaranteed:
				guaranteed_purposes.append(int(_RoomPurposeScript.from_name(str(g))))

		for p_key in arch_profile.room_purpose_distribution:
			var purp_type = int(_RoomPurposeScript.from_name(str(p_key)))
			distribution_weights[purp_type] = float(arch_profile.room_purpose_distribution[p_key])

	var last_assigned_purpose: int = -1
	var consecutive_count: int = 0
	var satisfied_guaranteed: Dictionary = {}

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

		var chosen_purpose: int = _RoomPurposeScript.Type.GENERIC

		# 1. Verificar si hay un propósito garantizado aplicable para este rol
		var allowed_purposes: Array = _get_allowed_purposes(arch_profile, legacy_profile, gameplay_role)
		var found_guaranteed: bool = false
		for g_purp in guaranteed_purposes:
			if not satisfied_guaranteed.has(g_purp) and allowed_purposes.has(g_purp):
				chosen_purpose = g_purp
				satisfied_guaranteed[g_purp] = true
				found_guaranteed = true
				break

		if not found_guaranteed:
			if gameplay_role == "EXPLORE" and not distribution_weights.is_empty():
				# Asignación macro basada en room_purpose_distribution
				chosen_purpose = _pick_distribution_purpose(
					distribution_weights,
					rare_purposes,
					last_assigned_purpose,
					consecutive_count,
					max_consecutive,
					rng
				)
			else:
				# Asignación contextual basada en gameplay_purpose_map + purpose_weights
				var weights_dict: Dictionary = _get_purpose_weights(arch_profile, legacy_profile)
				chosen_purpose = _pick_weighted_purpose(allowed_purposes, weights_dict, rng)

		if chosen_purpose == last_assigned_purpose:
			consecutive_count += 1
		else:
			consecutive_count = 1
			last_assigned_purpose = chosen_purpose

		result[r_id] = chosen_purpose


	return result

func _get_allowed_purposes(arch_prof: _ProfileArchetypeScript, leg_prof: _DungeonArchetypeProfileScript, role: String) -> Array:
	if arch_prof != null:
		var list = arch_prof.get_allowed_purposes_for_gameplay(StringName(role))
		var arr: Array = []
		for item in list:
			arr.append(int(_RoomPurposeScript.from_name(str(item))))
		return arr
	if leg_prof != null:
		return leg_prof.get_allowed_purposes_for_gameplay(role)
	return [_RoomPurposeScript.Type.GENERIC]

func _get_purpose_weights(arch_prof: _ProfileArchetypeScript, leg_prof: _DungeonArchetypeProfileScript) -> Dictionary:
	var result: Dictionary = {}
	if arch_prof != null:
		for k in arch_prof.purpose_weights:
			var purp = int(_RoomPurposeScript.from_name(str(k)))
			result[purp] = float(arch_prof.purpose_weights[k])
		return result
	if leg_prof != null:
		return leg_prof.purpose_weights
	return result

func _pick_distribution_purpose(
	distribution_weights: Dictionary,
	rare_purposes: Array[int],
	last_purpose: int,
	consecutive_count: int,
	max_consecutive: int,
	rng: RandomNumberGenerator
) -> int:
	var candidates: Array[int] = []
	var weights: Dictionary = {}

	for p in distribution_weights:
		# Excluir entradas con peso <= 0 o salas raras (reservadas a roles especiales como BOSS)
		if distribution_weights[p] <= 0.0 or rare_purposes.has(p):
			continue

		# Si ya alcanzamos el límite consecutivo, excluir temporalmente ese propósito
		if p == last_purpose and consecutive_count >= max_consecutive:
			continue

		candidates.append(p)
		weights[p] = distribution_weights[p]

	if candidates.is_empty():
		# Fallback si todos fueron filtrados
		for p in distribution_weights:
			if not rare_purposes.has(p):
				return p
		return _RoomPurposeScript.Type.GENERIC

	return _pick_weighted_purpose(candidates, weights, rng)

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

