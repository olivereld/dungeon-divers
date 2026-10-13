class_name FoliageSpecies
extends Resource

## Define la representación visual y comportamiento de distribución de una especie de follaje
## (por ejemplo, hierba alta, césped corto, flores, juncos). Totalmente independiente del bioma.

@export var id: StringName = &"grass_common"
@export var display_name: String = "Common Grass"
@export var texture_path: String = "res://assets/texture/foliage/grass/large_grass_01.jpg"
@export var density_weight: float = 1.0
@export var scale_min: Vector3 = Vector3(0.85, 0.85, 0.85)
@export var scale_max: Vector3 = Vector3(1.25, 1.30, 1.25)
@export var max_slope: float = 25.0
@export var color_bottom: Color = Color(0.20, 0.20, 0.10)
@export var color_top: Color = Color(0.38, 0.44, 0.18)
@export var quad_cross_count: int = 2
@export var gradient_texture_path: String = ""
@export var use_upward_normals: bool = true
@export var wind_strength: float = -1.0
@export var wind_speed: float = -1.0

func _init(
	p_id: StringName = &"grass_common",
	p_display_name: String = "Common Grass",
	p_texture_path: String = "res://assets/texture/foliage/grass/large_grass_01.jpg",
	p_density_weight: float = 1.0,
	p_scale_min: Vector3 = Vector3(0.85, 0.85, 0.85),
	p_scale_max: Vector3 = Vector3(1.25, 1.30, 1.25),
	p_max_slope: float = 25.0,
	p_color_bottom: Color = Color(0.20, 0.20, 0.10),
	p_color_top: Color = Color(0.38, 0.44, 0.18),
	p_quad_cross_count: int = 2,
	p_gradient_texture_path: String = "",
	p_use_upward_normals: bool = true,
	p_wind_strength: float = -1.0,
	p_wind_speed: float = -1.0
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
	gradient_texture_path = p_gradient_texture_path
	use_upward_normals = p_use_upward_normals
	wind_strength = p_wind_strength
	wind_speed = p_wind_speed
