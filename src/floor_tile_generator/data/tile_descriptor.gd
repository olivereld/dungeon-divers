class_name TileDescriptor
extends RefCounted

## DTO inmutable de datos puros que describe una losa o piedra individual antes de generar la malla.

var rect: Rect2
var height: float
var bevel: float
var color_mod: float
var material_variant: int
var rotation_deg: float
var world_offset: Vector2
var polygon_2d: PackedVector2Array
var height_tilt: Vector2

func _init(
	p_rect: Rect2 = Rect2(),
	p_height: float = 0.06,
	p_bevel: float = 0.025,
	p_color_mod: float = 0.0,
	p_material_variant: int = 0,
	p_rotation_deg: float = 0.0,
	p_world_offset: Vector2 = Vector2.ZERO,
	p_polygon_2d: PackedVector2Array = PackedVector2Array(),
	p_height_tilt: Vector2 = Vector2.ZERO
) -> void:
	rect = p_rect
	height = p_height
	bevel = p_bevel
	color_mod = p_color_mod
	material_variant = p_material_variant
	rotation_deg = p_rotation_deg
	world_offset = p_world_offset
	polygon_2d = p_polygon_2d
	height_tilt = p_height_tilt
