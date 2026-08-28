class_name ProfileArchetypeStyle
extends RefCounted

## Estilo arquitectónico y referencia de materiales de un arquetipo.

var floor_style: StringName = &"generic"
var wall_style: StringName = &"generic"
var door_style: StringName = &"generic"
var stairs_style: StringName = &"generic"
var material_profile: StringName = &"generic_stone"

func _init(
	p_floor: StringName = &"generic",
	p_wall: StringName = &"generic",
	p_door: StringName = &"generic",
	p_stairs: StringName = &"generic",
	p_mat: StringName = &"generic_stone"
) -> void:
	floor_style = p_floor
	wall_style = p_wall
	door_style = p_door
	stairs_style = p_stairs
	material_profile = p_mat
