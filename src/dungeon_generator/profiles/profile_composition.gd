class_name ProfileComposition
extends RefCounted

## Composición espacial de una sala agrupando regla primaria y secundarias.

const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")

var primary: _ProfileCompositionRuleScript = null
var secondary: Array[_ProfileCompositionRuleScript] = []

func _init(
	p_primary: _ProfileCompositionRuleScript = null,
	p_secondary: Array[_ProfileCompositionRuleScript] = []
) -> void:
	primary = p_primary
	secondary = p_secondary

func get_all_rules() -> Array[_ProfileCompositionRuleScript]:
	var rules: Array[_ProfileCompositionRuleScript] = []
	if primary != null:
		rules.append(primary)
	rules.append_array(secondary)
	return rules
