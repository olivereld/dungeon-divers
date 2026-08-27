class_name ProfileWallVariantPolicy
extends RefCounted

## Política tipada de variantes de muro cargada desde el perfil de sala JSON.

var enabled: bool = true
var allowed: Array[StringName] = [&"normal"]
var weights: Dictionary = { &"normal": 100.0 } # StringName -> float

func _init(
	p_enabled: bool = true,
	p_allowed: Array[StringName] = [&"normal"],
	p_weights: Dictionary = {}
) -> void:
	enabled = p_enabled
	allowed = p_allowed
	if p_weights.is_empty():
		weights = { &"normal": 100.0 }
	else:
		weights = p_weights

func get_weight_for_variant(variant_name: StringName) -> float:
	return float(weights.get(variant_name, 0.0))
