class_name FoliageSpecies
extends Resource

## Define la representación visual y comportamiento de distribución de una especie de follaje
## (por ejemplo, hierba alta, césped corto, flores, hongos). Totalmente independiente del bioma.

enum ScaleCategory {
	MICRO = 0,   ## Césped / hierba baja / pequeños hongos (10-35cm)
	MEDIUM = 1,  ## Hierba alta / helechos / flores / clusters de hongos (40cm-1.2m)
	MACRO = 2    ## Arbustos grandes / árboles (1.5-8m+)
}

enum FoliageType {
	GRASS = 0,
	FLOWER = 1,
	MUSHROOM = 2
}

@export var id: StringName = &"grass_common"
@export var display_name: String = "Common Grass"
@export var foliage_type: FoliageType = FoliageType.GRASS
@export var scale_category: ScaleCategory = ScaleCategory.MICRO
@export var texture_path: String = "res://assets/texture/foliage/grass/large_grass_01.jpg"
@export var density_weight: float = 1.0
@export var scale_min: Vector3 = Vector3(0.85, 0.85, 0.85)
@export var scale_max: Vector3 = Vector3(1.25, 1.30, 1.25)
@export var scale_weights: Dictionary = {"small": 0.70, "medium": 0.25, "large": 0.05}
@export var small_mult_range: Vector2 = Vector2(0.75, 0.95)
@export var medium_mult_range: Vector2 = Vector2(0.95, 1.15)
@export var large_mult_range: Vector2 = Vector2(1.15, 1.35)
@export var max_slope: float = 25.0
@export var color_bottom: Color = Color(0.20, 0.20, 0.10)
@export var color_top: Color = Color(0.38, 0.44, 0.18)
@export var quad_cross_count: int = 2
@export var gradient_texture_path: String = ""
@export var gradient_influence: float = -1.0
@export var tint_with_grass_color: bool = true
@export var canopy_preference: float = 0.0
@export var use_upward_normals: bool = true
@export var bark_texture_path: String = ""
@export var bark_influence: float = 0.75
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
	p_wind_speed: float = -1.0,
	p_foliage_type: FoliageType = FoliageType.GRASS,
	p_tint_with_grass_color: bool = true,
	p_gradient_influence: float = -1.0,
	p_canopy_preference: float = 0.0
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
	foliage_type = p_foliage_type
	tint_with_grass_color = p_tint_with_grass_color
	gradient_influence = p_gradient_influence
	canopy_preference = p_canopy_preference
