class_name HangingAnchor
extends "res://src/presentation/fixtures/fixture_anchor.gd"

## Anclaje suspendido de punto superior / techo / bóveda.
## Provisionalmente derivado con elevación vertical sobre suelo libre hasta la integración de geometría estructural de techo/vigas.

var suspension_height: float = 2.4

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_suspension_height: float = 2.4
) -> void:
	self.mode = _FixturePlacementModeScript.Mode.HANGING
	self.cell = p_cell
	self.position = p_pos
	self.rotation_y = p_rot_y
	self.normal = Vector3.DOWN
	self.suspension_height = p_suspension_height
