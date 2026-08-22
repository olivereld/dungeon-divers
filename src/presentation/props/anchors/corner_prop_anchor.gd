class_name CornerPropAnchor
extends "res://src/presentation/props/prop_anchor.gd"

## Anchor para props de esquina (ej. urnas funerarias, cofres, escombros arrinconados).

func _init(p_cell: Vector2i = Vector2i.ZERO, p_world_pos: Vector3 = Vector3.ZERO, p_rot_y: float = 0.0) -> void:
	super._init(_PropPlacementModeScript.Mode.CORNER, p_cell, p_world_pos, p_rot_y)
	self.mode = _PropPlacementModeScript.Mode.CORNER
