class_name PropAnchor
extends RefCounted

## Punto espacial potencial de colocación para un Prop dentro de una habitación.
## Describe ubicación, celda, rotación y contexto topológico sin crear Nodes ni decidir qué objeto instanciar.

const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

var mode: int = _PropPlacementModeScript.Mode.FLOOR
var cell: Vector2i = Vector2i.ZERO
var world_position: Vector3 = Vector3.ZERO
var rotation_degrees_y: float = 0.0
var wall_side: Vector2i = Vector2i.ZERO
var available_size: Vector2i = Vector2i.ONE

func _init(
	p_mode: int = _PropPlacementModeScript.Mode.FLOOR,
	p_cell: Vector2i = Vector2i.ZERO,
	p_world_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0
) -> void:
	mode = p_mode
	cell = p_cell
	world_position = p_world_pos
	rotation_degrees_y = p_rot_y
