class_name ProfileFloorVariantPolicy
extends RefCounted

## Política declarativa de variantes arquitectónicas de superficie para suelos de una sala.
## Deserializada desde el bloque "floor" o "floor_variants" en rooms/*.json.

var enabled: bool = false
var base_style: StringName = &""
var base_weight: float = 100.0
var variants: Array[Dictionary] = [] # Array of { "style": StringName, "weight": float }
var distribution_mode: StringName = &"weighted"

func _init(
	p_enabled: bool = false,
	p_base_style: StringName = &"",
	p_base_weight: float = 100.0,
	p_variants: Array = [],
	p_dist_mode: StringName = &"weighted"
) -> void:
	enabled = p_enabled
	base_style = p_base_style
	base_weight = p_base_weight
	variants = []
	for v in p_variants:
		if v is Dictionary:
			variants.append({
				"style": StringName(str(v.get("style", ""))),
				"weight": float(v.get("weight", 0.0))
			})
	distribution_mode = p_dist_mode

func get_total_weight() -> float:
	var total: float = base_weight
	for v in variants:
		total += float(v.get("weight", 0.0))
	return total

func to_dict() -> Dictionary:
	return {
		"enabled": enabled,
		"base_style": String(base_style),
		"base_weight": base_weight,
		"variants": variants,
		"distribution_mode": String(distribution_mode)
	}
