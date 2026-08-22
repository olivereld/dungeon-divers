class_name FloorAnchor
extends "res://src/presentation/fixtures/fixture_anchor.gd"

## Anclaje en plano de suelo horizontal.

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0
) -> void:
	self.mode = _FixturePlacementModeScript.Mode.FLOOR
	self.cell = p_cell
	self.position = p_pos
	self.rotation_y = p_rot_y
	self.normal = Vector3.UP
