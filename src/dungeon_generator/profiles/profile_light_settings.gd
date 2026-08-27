class_name ProfileLightSettings
extends RefCounted

## Parámetros tipados de iluminación (Color, Energy, Range) para salas, slots o assets específicos.

var color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var energy: float = -1.0
var light_range: float = -1.0

var has_color_override: bool = false
var has_energy_override: bool = false
var has_range_override: bool = false

func _init(
	p_color: Color = Color(-1.0, -1.0, -1.0, -1.0),
	p_energy: float = -1.0,
	p_range: float = -1.0
) -> void:
	color = p_color
	energy = p_energy
	light_range = p_range
	has_color_override = (color.a >= 0.0)
	has_energy_override = (energy != -1.0)
	has_range_override = (light_range != -1.0)

func has_color() -> bool:
	return has_color_override

func has_energy() -> bool:
	return has_energy_override

func has_range() -> bool:
	return has_range_override

func is_empty() -> bool:
	return not has_color() and not has_energy() and not has_range()
