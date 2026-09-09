class_name WorldVegetationItem
extends RefCounted

enum Type {
	CONIFER,
	SHRUB,
	ROCK,
}

var type: Type
var position: Vector3
var rotation_y: float
var scale: float

func _init(p_type: Type, p_pos: Vector3, p_rot: float = 0.0, p_scale: float = 1.0) -> void:
	type = p_type
	position = p_pos
	rotation_y = p_rot
	scale = p_scale
