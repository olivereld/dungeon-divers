class_name FloorVariantResolver
extends RefCounted

## Resolvedor determinista de variantes de baldosas y superficies de suelo.
## Muestrea estocásticamente las variantes ponderadas definidas en ProfileFloorVariantPolicy
## de manera 100% pura y reproducible sin acoplamiento a nodos ni mallas.

const _ProfileFloorVariantPolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func resolve_cell_floor_style(
	cell_pos: Vector2i,
	room_seed: int,
	policy: _ProfileFloorVariantPolicyScript = null,
	fallback_style: int = _ArchStyleScript.FloorStyle.CATACOMB_DIRT
) -> int: # Returns ArchitecturalStyle.FloorStyle
	if policy == null or not policy.enabled or policy.variants.is_empty():
		if policy != null and policy.base_style != &"":
			return _ArchStyleScript.floor_from_name(str(policy.base_style), fallback_style)
		return fallback_style

	var total_weight: float = policy.get_total_weight()
	if total_weight <= 0.0:
		return _ArchStyleScript.floor_from_name(str(policy.base_style), fallback_style)

	# Hash determinista de celda espacial
	var cell_hash: int = (room_seed ^ (cell_pos.x * 73856093) ^ (cell_pos.y * 19349663) ^ 0x5F3759DF) & 0x7FFFFFFF
	var normalized_roll: float = float(cell_hash % 100000) / 100000.0 * total_weight

	# 1. Comprobar peso de base
	if normalized_roll < policy.base_weight:
		return _ArchStyleScript.floor_from_name(str(policy.base_style), fallback_style)

	# 2. Comprobar variantes ponderadas
	var accum: float = policy.base_weight
	for v in policy.variants:
		var w: float = float(v.get("weight", 0.0))
		accum += w
		if normalized_roll < accum:
			var v_name: String = str(v.get("style", ""))
			return _ArchStyleScript.floor_from_name(v_name, fallback_style)

	# Fallback a base
	return _ArchStyleScript.floor_from_name(str(policy.base_style), fallback_style)
