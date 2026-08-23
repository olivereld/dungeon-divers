class_name DecorationPurposeProfile
extends Resource

## Perfil integral de composición y semántica espacial asignado a un propósito de habitación.

const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _DecorationCompositionTemplateScript = preload("res://src/presentation/decoration/composition/decoration_composition_template.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")

@export var purpose_type: int = 0
@export var intent: _DecorationRoomIntentScript = null
@export var templates: Array[_DecorationCompositionTemplateScript] = []
@export var fixture_rules: Array[_FixtureBudgetRuleScript] = []
@export var default_lighting_budget: float = 5.0
