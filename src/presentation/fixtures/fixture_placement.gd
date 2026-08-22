class_name FixturePlacement
extends RefCounted

## Estructura inmutable que encapsula la ubicación física, modo y orientación de un fixture.

const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

var mode: int = _FixturePlacementModeScript.Mode.WALL
var cell: Vector2i = Vector2i.ZERO
var wall_side: int = -1 # 0=NORTH, 1=EAST, 2=SOUTH, 3=WEST, -1=N/A
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var normal: Vector3 = Vector3.ZERO

func _init(
	p_mode: int = _FixturePlacementModeScript.Mode.WALL,
	p_cell: Vector2i = Vector2i.ZERO,
	p_side: int = -1,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_normal: Vector3 = Vector3.ZERO
) -> void:
	mode = p_mode
	cell = p_cell
	wall_side = p_side
	position = p_pos
	rotation_y = p_rot_y
	normal = p_normal

func to_debug_string() -> String:
	return "FixturePlacement(Mode: %s, Cell: %s, Side: %d, Pos: %s, RotY: %.2f)" % [
		_FixturePlacementModeScript.mode_to_name(mode), str(cell), wall_side, str(position), rotation_y
	]
