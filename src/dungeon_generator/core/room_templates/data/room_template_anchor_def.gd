class_name RoomTemplateAnchorDef
extends RefCounted

## Declaración de un ancla arquitectónica en un RoomTemplate.
## No especifica meshes ni escenas; define un punto de interés espacial
## requerido u opcional (focal, altar, relic, entrance, corner) para las capas superiores.

var id: StringName = &""
var required: bool = true
var location_hint: StringName = &"center" # &"center", &"wall", &"opposite_entrance", &"corner", &"perimeter"

var location: StringName:
	get:
		return location_hint
	set(value):
		location_hint = value

func _init(
	p_id: StringName = &"",
	p_required: bool = true,
	p_location_hint: StringName = &"center"
) -> void:
	id = p_id
	required = p_required
	location_hint = p_location_hint
