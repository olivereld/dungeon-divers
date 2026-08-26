class_name ProfileComposition
extends RefCounted

## Composición espacial de una sala agrupando regla primaria, secundarias y de soporte.

const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")

var primary: _ProfileCompositionRuleScript = null
var secondary: Array[_ProfileCompositionRuleScript] = []
var support: Array[_ProfileCompositionRuleScript] = []

func _init(
	p_primary: _ProfileCompositionRuleScript = null,
	p_secondary: Array[_ProfileCompositionRuleScript] = [],
	p_support: Array[_ProfileCompositionRuleScript] = []
) -> void:
	primary = p_primary
	secondary = p_secondary
	support = p_support

func get_all_rules() -> Array[_ProfileCompositionRuleScript]:
	var rules: Array[_ProfileCompositionRuleScript] = []
	if primary != null:
		rules.append(primary)
	rules.append_array(secondary)
	rules.append_array(support)
	return rules

func get_rules_by_role() -> Dictionary:
	var prim_arr: Array[_ProfileCompositionRuleScript] = []
	if primary != null:
		prim_arr.append(primary)
	return {
		"primary": prim_arr,
		"secondary": secondary,
		"support": support
	}

