class_name RoomTemplateSymmetryPolicy
extends RefCounted

## Política de simetría arquitectónica para RoomTemplates.
## Controla si la habitación exige simetría espacial formal y a lo largo de qué eje(s).

var required: bool = false
var axis: StringName = &"none" # &"none", &"vertical", &"horizontal", &"both", &"radial"
var tolerance: int = 0

func _init(
	p_required: bool = false,
	p_axis: StringName = &"none",
	p_tolerance: int = 0
) -> void:
	required = p_required
	axis = p_axis
	tolerance = p_tolerance
