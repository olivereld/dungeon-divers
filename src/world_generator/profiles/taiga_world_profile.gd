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
