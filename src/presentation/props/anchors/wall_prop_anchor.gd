class_name WallPropAnchor
extends "res://src/presentation/props/prop_anchor.gd"

## Anchor para props adosados a muros (ej. librerías, bancos pegados a la pared).

func _init(p_cell: Vector2i = Vector2i.ZERO, p_world_pos: Vector3 = Vector3.ZERO, p_rot_y: float = 0.0, p_side: Vector2i = Vector2i.ZERO) -> void:
	super._init(_PropPlacementModeScript.Mode.WALL, p_cell, p_world_pos, p_rot_y)
	self.mode = _PropPlacementModeScript.Mode.WALL
	self.wall_side = p_side
