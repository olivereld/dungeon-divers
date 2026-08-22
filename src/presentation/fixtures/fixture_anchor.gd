class_name FixtureAnchor
extends RefCounted

## Anclaje base para colocación de fixtures arquitectónicos.
## 100% puro e inmutable.

const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

var mode: int = _FixturePlacementModeScript.Mode.WALL
var cell: Vector2i = Vector2i.ZERO
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var normal: Vector3 = Vector3.UP

func _init(
	p_mode: int = _FixturePlacementModeScript.Mode.WALL,
	p_cell: Vector2i = Vector2i.ZERO,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_normal: Vector3 = Vector3.UP
) -> void:
	mode = p_mode
	cell = p_cell
	position = p_pos
	rotation_y = p_rot_y
	normal = p_normal
