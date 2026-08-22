class_name DecorationCompositionProfile
extends Resource

## Perfil declarativo integral de composición para un tipo de habitación.
## Describe la intención espacial (plantilla) independientemente de los assets concretos.

const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")

@export var id: StringName = &""
@export var rules: Array[_DecorationCompositionRuleScript] = []
@export var max_total_props: int = 8
@export var lighting_budget: float = 6.0
