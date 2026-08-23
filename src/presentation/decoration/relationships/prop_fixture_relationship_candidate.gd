class_name PropFixtureRelationshipCandidate
extends RefCounted

## Candidato evaluado espacialmente para instanciar un Fixture relacionado con un Prop.

var prop_id: StringName = &""
var prop_cell: Vector2i = Vector2i.ZERO
var fixture_cell: Vector2i = Vector2i.ZERO
var fixture_style = null
var placement_mode: int = 0
var world_position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var normal: Vector3 = Vector3.UP

var distance_score: float = 0.0
var direction_score: float = 0.0
var clearance_score: float = 0.0
var total_score: float = 0.0
var is_valid: bool = true

func _init(
	p_prop_id: StringName = &"",
	p_prop_cell: Vector2i = Vector2i.ZERO,
	p_fixture_cell: Vector2i = Vector2i.ZERO,
	p_style = null,
	p_mode: int = 0,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_normal: Vector3 = Vector3.UP
) -> void:
	prop_id = p_prop_id
	prop_cell = p_prop_cell
	fixture_cell = p_fixture_cell
	fixture_style = p_style
	placement_mode = p_mode
	world_position = p_pos
	rotation_y = p_rot_y
	normal = p_normal
