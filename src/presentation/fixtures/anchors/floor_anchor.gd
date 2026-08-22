class_name FloorAnchor
extends FixtureAnchor

## Anclaje en plano de suelo horizontal.

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0
) -> void:
	mode = 1 # FLOOR
	cell = p_cell
	position = p_pos
	rotation_y = p_rot_y
	normal = Vector3.UP
