class_name WallVariantResolver
extends RefCounted

## Resolutor puro y determinista de variantes arquitectónicas para WallSections.
## Selecciona la variante adecuada evaluando los pesos configurados en la política de la sala
## a través de un RNG determinista inicializado con la semilla maestra, ID de componente, sección y sala.

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")

func resolve_section_variant(
	section: _WallSectionScript,
	policy, # WallVariantPolicy o ProfileWallVariantPolicy
	master_seed: int = 1337
) -> StringName:
	if section == null:
		return &"normal"

	if policy == null or not policy.enabled:
		return &"normal"

	var allowed: Array = policy.allowed if ("allowed" in policy) else policy.allowed_variants
	var weights: Dictionary = policy.weights if ("weights" in policy) else policy.variant_weights

	if allowed.is_empty():
		return &"normal"

	# Filtrar variantes con peso positivo
	var candidate_variants: Array[StringName] = []
	var cumulative_weights: Array[float] = []
	var total_weight: float = 0.0

	for v in allowed:
		var v_name = StringName(v)
		var w = float(weights.get(v_name, weights.get(str(v_name), 0.0)))
		if w > 0.0:
			candidate_variants.append(v_name)
			total_weight += w
			cumulative_weights.append(total_weight)

	if candidate_variants.is_empty() or total_weight <= 0.0:
		return &"normal"

	if candidate_variants.size() == 1:
		return candidate_variants[0]

	# Semilla determinista derivada de coordenadas, IDs y semilla maestra
	var h_str = "%d:%d:%d:%d:%d:%d" % [
		master_seed,
		section.component_id,
		section.id,
		section.room_id,
		section.start_point.x,
		section.start_point.y
	]
	var seed_val: int = hash(h_str)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var roll: float = rng.randf_range(0.0, total_weight)
	for i in range(cumulative_weights.size()):
		if roll <= cumulative_weights[i]:
			return candidate_variants[i]

	return candidate_variants[candidate_variants.size() - 1]
