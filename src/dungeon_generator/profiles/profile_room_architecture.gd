class_name ProfileRoomArchitecture
extends RefCounted

## Configuración arquitectónica de la sala deserializada desde el bloque "architecture" en rooms/*.json.

var floor: StringName = &""
var walls: StringName = &""
var door: StringName = &""
var stairs: StringName = &""

func _init(
	p_floor: StringName = &"",
	p_walls: StringName = &"",
	p_door: StringName = &"",
	p_stairs: StringName = &""
) -> void:
	floor = p_floor
	walls = p_walls
	door = p_door
	stairs = p_stairs
