class_name RoomTemplateEntrancePolicy
extends RefCounted

## Política de restricciones de accesos y puertas para RoomTemplates.
## Define cardinalidad mínima/máxima de accesos, lados permitidos,
## separación mínima entre vanos contiguos y si se admiten entradas en esquinas.

var min_count: int = 1
var max_count: int = 4
var allowed_sides: Array[StringName] = [&"north", &"south", &"east", &"west"]
var allow_corner: bool = false
var min_spacing: int = 2

func _init(
	p_min_count: int = 1,
	p_max_count: int = 4,
	p_allowed_sides: Array[StringName] = [&"north", &"south", &"east", &"west"],
	p_allow_corner: bool = false,
	p_min_spacing: int = 2
) -> void:
	min_count = p_min_count
	max_count = p_max_count
	if not p_allowed_sides.is_empty():
		allowed_sides = p_allowed_sides
	allow_corner = p_allow_corner
	min_spacing = p_min_spacing

func allows_side(side: StringName) -> bool:
	return allowed_sides.has(side)
