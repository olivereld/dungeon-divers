class_name RockSizeProfile
extends RefCounted

## Define las características geométricas y de distribución para una categoría de roca.
## Módulo independiente y autónomo.

enum Category {
	LARGE = 0,
	MEDIUM = 1,
	SMALL = 2
}

var category: int = Category.MEDIUM
var category_name: String = "Medium"
var min_scale: float = 1.0
var max_scale: float = 2.5
var height_ratio: float = 1.0
var irregularity: float = 0.5
var segments: int = 8
var rings: int = 4
var density: float = 0.15
var cluster_probability: float = 0.35
var max_slope_degrees: float = 40.0
var num_variants: int = 4
var base_penetration: float = 0.25 ## Fracción de radio que penetra el suelo para evitar flotación

func _init(
	p_category: int = Category.MEDIUM,
	p_category_name: String = "Medium",
	p_min_scale: float = 1.0,
	p_max_scale: float = 2.5,
	p_height_ratio: float = 1.0,
	p_irregularity: float = 0.5,
	p_segments: int = 8,
	p_rings: int = 4,
	p_density: float = 0.15,
	p_cluster_prob: float = 0.35,
	p_max_slope: float = 40.0,
	p_num_variants: int = 4,
	p_base_penetration: float = 0.25
) -> void:
	category = p_category
	category_name = p_category_name
	min_scale = p_min_scale
	max_scale = p_max_scale
	height_ratio = p_height_ratio
	irregularity = p_irregularity
	segments = p_segments
	rings = p_rings
	density = p_density
	cluster_probability = p_cluster_prob
	max_slope_degrees = p_max_slope
	num_variants = p_num_variants
	base_penetration = p_base_penetration

static func create_large() -> RockSizeProfile:
	return new(
		Category.LARGE,
		"Large",
		2.5,   # min_scale
		5.0,   # max_scale
		1.1,   # height_ratio (más imponentes y verticales)
		0.75,  # irregularity (alta)
		9,     # segments (8-10)
		5,     # rings (4-5)
		0.03,  # density (muy baja)
		0.60,  # cluster_probability (alta formación de grupos a su alrededor)
		45.0,  # max_slope
		3,     # num_variants (3 variantes para mallas grandes)
		0.35   # base_penetration
	)

static func create_medium() -> RockSizeProfile:
	return new(
		Category.MEDIUM,
		"Medium",
		1.0,   # min_scale
		2.5,   # max_scale
		0.95,  # height_ratio
		0.55,  # irregularity (media/alta)
		8,     # segments (7-9)
		4,     # rings (3-4)
		0.12,  # density (media/alta)
		0.40,  # cluster_probability
		40.0,  # max_slope
		4,     # num_variants (4 variantes)
		0.25   # base_penetration
	)

static func create_small() -> RockSizeProfile:
	return new(
		Category.SMALL,
		"Small",
		0.15,  # min_scale
		0.70,  # max_scale
		0.75,  # height_ratio (más aplastadas / fragmentos)
		0.40,  # irregularity (media)
		7,     # segments (6-8)
		3,     # rings (3)
		0.30,  # density (alta)
		0.20,  # cluster_probability
		50.0,  # max_slope
		3,     # num_variants (2-3 variantes)
		0.20   # base_penetration
	)

static func get_all_profiles() -> Dictionary:
	return {
		Category.LARGE: create_large(),
		Category.MEDIUM: create_medium(),
		Category.SMALL: create_small()
	}
