class_name ProfileArchetypeGlobalSettings
extends RefCounted

## Ajustes globales de generación para un arquetipo de dungeon.

var min_rooms: int = 8
var max_rooms: int = 20
var decoration_density: float = 0.65
var lighting_density: float = 0.55
var prop_density: float = 0.60
var fixture_density: float = 0.55

func _init(
	p_min: int = 8,
	p_max: int = 20,
	p_decor: float = 0.65,
	p_light: float = 0.55,
	p_prop: float = 0.60,
	p_fix: float = 0.55
) -> void:
	min_rooms = p_min
	max_rooms = p_max
	decoration_density = p_decor
	lighting_density = p_light
	prop_density = p_prop
	fixture_density = p_fix
