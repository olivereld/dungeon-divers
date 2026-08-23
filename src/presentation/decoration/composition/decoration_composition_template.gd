class_name DecorationCompositionTemplate
extends Resource

## Plantilla declarativa de composición espacial reutilizable e independiente de assets concretos.

const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")

@export var template_id: StringName = &""
@export var primary_rule: _DecorationCompositionRuleScript = null
@export var support_rules: Array[_DecorationCompositionRuleScript] = []
@export var lighting_rules: Array[_DecorationCompositionRuleScript] = []
@export var min_room_size: Vector2i = Vector2i(4, 4)

func is_room_size_compatible(room_dimensions: Vector2i) -> bool:
	return room_dimensions.x >= min_room_size.x and room_dimensions.y >= min_room_size.y

func get_all_rules() -> Array[_DecorationCompositionRuleScript]:
	var result: Array[_DecorationCompositionRuleScript] = []
	if primary_rule != null:
		result.append(primary_rule)
	result.append_array(support_rules)
	result.append_array(lighting_rules)
	return result
