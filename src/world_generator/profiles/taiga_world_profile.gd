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

	# Pure Boreal Land Palette (Zero Blue in Terrain Mesh)
	terrain_loam_color = Color("#3e3830")   # Humus orgánico / turba
	terrain_moss_color = Color("#4a5338")   # Musgo y sotobosque
	terrain_grass_color = Color("#3f4f34")  # Hierba boreal desaturada
	forest_floor_color = Color("#25311e")   # Mantillo de acículas umbrío
	terrain_rock_color = Color("#464648")   # Granito frío
	terrain_snow_color = Color("#d8e2eb")   # Escarcha y cumbres

	terrain_low_color = terrain_loam_color
	terrain_mid_color = terrain_grass_color
	terrain_high_color = terrain_snow_color
	terrain_slope_color = terrain_rock_color
	clearing_color = terrain_moss_color
	forest_color = forest_floor_color

	# Hydrology Defaults
	hydrology_enabled = true
	lake_threshold = 0.22
	lake_minimum_area = 4
	max_rivers = 3
	river_source_min_height = 0.65
	river_source_min_slope = 4.0
	min_river_length = 12.0
	max_river_length = 180.0
	river_max_steps = 250
	river_min_width = 0.8
	river_max_width = 2.4
	river_meander_strength = 0.18
	hydrology_noise_enabled = true
	hydrology_noise_frequency = 0.02
	hydrology_noise_strength = 0.25
	hydrology_noise_octaves = 2
	hydrology_noise_seed_offset = 707
	water_color_shallow = Color("#2a68a8")
	water_color_medium = Color("#1e4e82")
	water_color_deep = Color("#143254")
	water_color_river = Color("#2d74b8")
	water_color_lake = Color("#193e68")
	water_roughness = 0.08
	water_transparency = 0.85


