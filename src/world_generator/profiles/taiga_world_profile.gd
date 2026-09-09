class_name TaigaWorldProfile
extends WorldProfile

func _init() -> void:
	width = 128
	height = 128
	cell_size = 1.0

	# Taiga terrain: rolling hills, wide valleys, moderate vertical relief
	macro_frequency = 0.012
	macro_strength = 14.0
	medium_frequency = 0.035
	medium_strength = 5.0
	detail_frequency = 0.10
	detail_strength = 1.0
	base_height = 1.5
	height_scale = 1.0
	relief_exponent = 1.1

	warp_enabled = true
	warp_frequency = 0.018
	warp_strength = 18.0
	warp_octaves = 2

	# Ecology: dense boreal evergreen forests broken by open peat/moss clearings
	forest_frequency = 0.025
	clearing_threshold = 0.45
	moisture_frequency = 0.02

	# Vegetation: high conifer presence, dispersed shrubs and granite rocks
	tree_density = 0.70
	shrub_density = 0.45
	rock_density = 0.20
	min_tree_spacing = 2.0
	max_walkable_slope = 35.0

	# Atmospheric Taiga Palette: mossy wetlands, temperate pine needle beds, granite rocks
	terrain_low_color = Color(0.20, 0.27, 0.16)
	terrain_mid_color = Color(0.27, 0.35, 0.21)
	terrain_high_color = Color(0.40, 0.42, 0.35)
	terrain_slope_color = Color(0.36, 0.35, 0.33)
	clearing_color = Color(0.36, 0.38, 0.20)
	forest_color = Color(0.15, 0.22, 0.13)

	color_deep_water = Color("#1a3a5c")
	color_water = Color("#2456a4")
	color_sand = Color("#c8a96e")
	color_ground = Color("#7a6548")
	color_grass = Color("#4a8c3f")
	color_forest = Color("#2d5a27")
	color_rock = Color("#5a5a5a")
	color_snow = Color("#dce8f0")

