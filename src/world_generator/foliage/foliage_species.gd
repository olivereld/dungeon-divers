class_name FoliageSpecies
extends Resource

## Define la representación visual y comportamiento de distribución de una especie de follaje
## (por ejemplo, hierba alta, césped corto, flores, juncos). Totalmente independiente del bioma.

@export var id: StringName = &"grass_common"
@export var display_name: String = "Common Grass"
@export var texture_path: String = "res://assets/texture/foliage/grass/large_grass_01.jpg"
@export var density_weight: float = 1.0
@export var scale_min: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var scale_max: Vector3 = Vector3(1.2, 1.2, 1.2)
@export var max_slope: float = 25.0
@export var color_bottom: Color = Color(0.20, 0.28, 0.16)
@export var color_top: Color = Color(0.45, 0.62, 0.30)
@export var quad_cross_count: int = 2

func _init(
	p_id: StringName = &"grass_common",
	p_display_name: String = "Common Grass",
	p_texture_path: String = "res://assets/texture/foliage/grass/large_grass_01.jpg",
	p_density_weight: float = 1.0,
	p_scale_min: Vector3 = Vector3(0.8, 0.8, 0.8),
	p_scale_max: Vector3 = Vector3(1.2, 1.2, 1.2),
	p_max_slope: float = 25.0,
	p_color_bottom: Color = Color(0.20, 0.28, 0.16),
	p_color_top: Color = Color(0.45, 0.62, 0.30),
	p_quad_cross_count: int = 2
) -> void:
	id = p_id
	display_name = p_display_name
	texture_path = p_texture_path
	density_weight = p_density_weight
	scale_min = p_scale_min
	scale_max = p_scale_max
	max_slope = p_max_slope
	color_bottom = p_color_bottom
	color_top = p_color_top
	quad_cross_count = p_quad_cross_count
