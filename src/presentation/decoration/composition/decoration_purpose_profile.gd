class_name DecorationPurposeProfile
extends Resource

## Perfil integral de composición y semántica espacial asignado a un propósito de habitación.

const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _DecorationCompositionTemplateScript = preload("res://src/presentation/decoration/composition/decoration_composition_template.gd")

@export var purpose_type: int = 0
@export var intent: _DecorationRoomIntentScript = null
@export var templates: Array[_DecorationCompositionTemplateScript] = []
@export var default_lighting_budget: float = 5.0
