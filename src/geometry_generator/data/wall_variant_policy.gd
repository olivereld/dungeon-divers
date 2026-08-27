class_name WallVariantPolicy
extends RefCounted

## Política de selección y distribución de variantes de muro.

var enabled: bool = true
var allowed_variants: Array[StringName] = [&"normal"]
var variant_weights: Dictionary = { &"normal": 100.0 }

func _init(p_enabled: bool = true, p_allowed: Array[StringName] = [&"normal"], p_weights: Dictionary = {}) -> void:
	enabled = p_enabled
	allowed_variants = p_allowed
	if p_weights.is_empty():
		variant_weights = { &"normal": 100.0 }
	else:
		variant_weights = p_weights
