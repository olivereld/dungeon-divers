class_name ProfileArchetypeStyle
extends RefCounted

## Estilo arquitectónico y referencia de materiales de un arquetipo.

var floor_style: StringName = &"mausoleum"
var wall_style: StringName = &"mausoleum"
var door_style: StringName = &"mausoleum"
var stairs_style: StringName = &"mausoleum"
var material_profile: StringName = &"mausoleum_stone"

func _init(
	p_floor: StringName = &"mausoleum",
	p_wall: StringName = &"mausoleum",
	p_door: StringName = &"mausoleum",
	p_stairs: StringName = &"mausoleum",
	p_mat: StringName = &"mausoleum_stone"
) -> void:
	floor_style = p_floor
	wall_style = p_wall
	door_style = p_door
	stairs_style = p_stairs
	material_profile = p_mat
