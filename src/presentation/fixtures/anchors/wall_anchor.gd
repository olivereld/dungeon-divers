class_name WallAnchor
extends "res://src/presentation/fixtures/fixture_anchor.gd"

## Anclaje en plano de muro vertical.

var wall_side: int = 0 # 0=NORTH, 1=EAST, 2=SOUTH, 3=WEST

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_wall_side: int = 0,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_normal: Vector3 = Vector3.ZERO
) -> void:
	self.mode = _FixturePlacementModeScript.Mode.WALL
	self.cell = p_cell
	self.wall_side = p_wall_side
	self.position = p_pos
	self.rotation_y = p_rot_y
	self.normal = p_normal
