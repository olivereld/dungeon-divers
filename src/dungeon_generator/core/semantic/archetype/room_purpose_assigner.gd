class_name RoomPurposeAssigner
extends RefCounted

## Algoritmo de asignación pura y determinista de propósitos arquitectónicos a cada habitación.
## Combina mapeo de roles de gameplay ("START", "BOSS", "TREASURE", "COMBAT") con la distribución
## macro (room_purpose_distribution) para salas de exploración y reglas de restricción (room_rules).

const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ProfileArchetypeScript = preload("res://src/dungeon_generator/profiles/profile_archetype.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")

func assign_purposes(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array, # Array[RoomData]
	objectives: Array, # Array[ObjectiveData]
	profile, # ProfileBundle or ProfileArchetype
	seed_val: int
) -> Dictionary:
	var result: Dictionary = {} # room_id (int) -> StringName
	if profile == null or rooms.is_empty():
		return result

	var arch_profile: _ProfileArchetypeScript = null

	if profile is _ProfileBundleScript:
		arch_profile = profile.archetype
	elif profile is _ProfileArchetypeScript:
		arch_profile = profile

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Indexar objetivos por room_id
	var room_objectives: Dictionary = {}
	for obj in objectives:
		room_objectives[obj.room_id] = obj

	# Extraer reglas de arquetipo si existen
	var max_consecutive: int = 2
	var rare_purposes: Array[StringName] = []
	var guaranteed_purposes: Array[StringName] = []
	var distribution_weights: Dictionary = {} # StringName -> float

	if arch_profile != null:
		if arch_profile.room_rules != null:
			max_consecutive = arch_profile.room_rules.max_same_purpose_consecutive
			for r in arch_profile.room_rules.rare:
				rare_purposes.append(_RoomPurposeScript.resolve_id(r))
			for g in arch_profile.room_rules.guaranteed:
				guaranteed_purposes.append(_RoomPurposeScript.resolve_id(g))

		for p_key in arch_profile.room_purpose_distribution:
			var purp_id = _RoomPurposeScript.resolve_id(p_key)
			distribution_weights[purp_id] = float(arch_profile.room_purpose_distribution[p_key])

	var last_assigned_purpose: StringName = &""
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

		var chosen_purpose: StringName = &"generic"

		# 1. Verificar si hay un propósito garantizado aplicable para este rol
		var allowed_purposes: Array[StringName] = _get_allowed_purposes(arch_profile, gameplay_role)
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
				var weights_dict: Dictionary = _get_purpose_weights(arch_profile)
				chosen_purpose = _pick_weighted_purpose(allowed_purposes, weights_dict, rng)

		if chosen_purpose == last_assigned_purpose:
			consecutive_count += 1
		else:
			consecutive_count = 1
			last_assigned_purpose = chosen_purpose

		result[r_id] = chosen_purpose

	return result

func _get_allowed_purposes(arch_prof: _ProfileArchetypeScript, role: String) -> Array[StringName]:
	if arch_prof != null:
		var list = arch_prof.get_allowed_purposes_for_gameplay(StringName(role))
		var arr: Array[StringName] = []
		for item in list:
			arr.append(_RoomPurposeScript.resolve_id(item))
		if not arr.is_empty():
			return arr
	return [&"generic"]

func _get_purpose_weights(arch_prof: _ProfileArchetypeScript) -> Dictionary:
	var result: Dictionary = {}
	if arch_prof != null:
		for k in arch_prof.purpose_weights:
			var purp = _RoomPurposeScript.resolve_id(k)
			result[purp] = float(arch_prof.purpose_weights[k])
		return result
	return result

func _pick_distribution_purpose(
	distribution_weights: Dictionary,
	rare_purposes: Array[StringName],
	last_purpose: StringName,
	consecutive_count: int,
	max_consecutive: int,
	rng: RandomNumberGenerator
) -> StringName:
	var candidates: Array[StringName] = []
	var weights: Dictionary = {}

	for p in distribution_weights:
		var purp_id: StringName = _RoomPurposeScript.resolve_id(p)
		# Excluir entradas con peso <= 0 o salas raras (reservadas a roles especiales como BOSS)
		if distribution_weights[p] <= 0.0 or rare_purposes.has(purp_id):
			continue

		# Si ya alcanzamos el límite consecutivo, excluir temporalmente ese propósito
		if purp_id == last_purpose and consecutive_count >= max_consecutive:
			continue

		candidates.append(purp_id)
		weights[purp_id] = distribution_weights[p]

	if candidates.is_empty():
		# Fallback si todos fueron filtrados
		for p in distribution_weights:
			var purp_id: StringName = _RoomPurposeScript.resolve_id(p)
			if not rare_purposes.has(purp_id):
				return purp_id
		return &"generic"

	return _pick_weighted_purpose(candidates, weights, rng)

func _pick_weighted_purpose(allowed: Array[StringName], weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	if allowed.is_empty():
		return &"generic"
	if allowed.size() == 1:
		return allowed[0]

	var total_weight: float = 0.0
	for p in allowed:
		total_weight += float(weights.get(p, 1.0))

	if total_weight <= 0.0:
		return allowed[0]

	var roll: float = rng.randf() * total_weight
	var accum: float = 0.0
	for p in allowed:
		accum += float(weights.get(p, 1.0))
		if roll <= accum:
			return p

	return allowed[allowed.size() - 1]
