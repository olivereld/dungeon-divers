class_name DecorationCompositionRule
extends Resource

## Regla declarativa de composición espacial para ubicar elementos primarios, secundarios o de iluminación.

const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")

@export var rule_id: StringName = &""
@export var composition_role: int = _CompositionRoleScript.Role.PRIMARY
@export var target_tags: Array[StringName] = []
@export var required_tags: Array[StringName] = []   ## ALL must be present on the style (AND logic)
@export var preferred_tags: Array[StringName] = []  ## Bonus affinity, not required
@export var forbidden_tags: Array[StringName] = []  ## ANY present on style -> exclude
@export var target_style_ids: Array[StringName] = []
@export var placement_mode: int = -1 ## -1 = auto (fall back to composition_role logic)
@export var orientation_mode: int = _DecorationOrientationModeScript.Mode.FACE_ROOM
@export var min_count: int = 1
@export var max_count: int = 1
@export var clearance: int = 1
@export var relationships: Array[Dictionary] = [] # Array de { "relation": int, "target_rule_id": StringName }
