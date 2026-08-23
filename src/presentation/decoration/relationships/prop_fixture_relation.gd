class_name PropFixtureRelation
extends Resource

## Regla declarativa de relación semántica y espacial entre un Prop colocado y sus Fixtures asociados.

const _PropFixtureRelationTypeScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_type.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")

@export var relation_id: StringName = &""
@export var prop_style_id: StringName = &""
@export var target_fixture_types: Array[int] = [] ## FixtureStyle.Type
@export var target_fixture_ids: Array[StringName] = []
@export var forbidden_fixture_types: Array[int] = []
@export var forbidden_fixture_ids: Array[StringName] = []

@export var relation_type: int = _PropFixtureRelationTypeScript.Type.COMPANION
@export var placement: int = _PropFixtureRelationPlacementScript.Placement.NEAR

@export var min_count: int = 1
@export var max_count: int = 2
@export var preferred_distance: float = 1.0
@export var max_distance: float = 2.5
@export var weight: float = 1.0

func _init(
	p_prop_id: StringName = &"",
	p_fixture_types: Array[int] = [],
	p_placement: int = _PropFixtureRelationPlacementScript.Placement.NEAR,
	p_min: int = 1,
	p_max: int = 2,
	p_relation_id: StringName = &"",
	p_pref_dist: float = 1.0,
	p_max_dist: float = 2.5,
	p_weight: float = 1.0,
	p_forbidden_types: Array[int] = []
) -> void:
	prop_style_id = p_prop_id
	target_fixture_types = p_fixture_types
	placement = p_placement
	min_count = p_min
	max_count = p_max
	relation_id = p_relation_id if p_relation_id != &"" else StringName(str(p_prop_id) + "_rel")
	preferred_distance = p_pref_dist
	max_distance = p_max_dist
	weight = p_weight
	forbidden_fixture_types = p_forbidden_types
