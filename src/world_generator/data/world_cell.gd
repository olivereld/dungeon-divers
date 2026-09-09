class_name WorldCell
extends RefCounted

var position: Vector2i
var height: float = 0.0
var normalized_height: float = 0.0
var slope: float = 0.0
var slope_category: int = 0
var is_walkable: bool = true

# Ecology
var forest_density: float = 0.0
var clearing_density: float = 0.0
var moisture: float = 0.0

func _init(p_pos: Vector2i = Vector2i.ZERO) -> void:
	position = p_pos
