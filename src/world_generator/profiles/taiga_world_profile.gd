class_name TaigaWorldProfile
extends WorldProfile

func _init() -> void:
	width = 128
	height = 128
	cell_size = 1.0

	# Taiga Physical Terrain Scale (Hierarchy: Macro 140m, Medium 45m, Detail 10m)
	macro_wavelength = 140.0
	macro_amplitude = 14.0
	medium_wavelength = 45.0
	medium_amplitude = 4.5
	detail_wavelength = 10.0
	detail_amplitude = 0.6
	base_height = 2.0
	height_scale = 1.0
	relief_exponent = 1.1

	# Legacy parameters synchronized
	macro_frequency = 1.0 / macro_wavelength
	macro_strength = macro_amplitude
	medium_frequency = 1.0 / medium_wavelength
	medium_strength = medium_amplitude
	detail_frequency = 1.0 / detail_wavelength
	detail_strength = detail_amplitude

	# Domain Warp Physical Scale
	warp_enabled = true
	warp_wavelength = 90.0
	warp_amplitude = 18.0
	warp_octaves = 2
	warp_frequency = 1.0 / warp_wavelength
	warp_strength = warp_amplitude

	# Ecology Physical Scale: vast boreal forest stands broken by peat clearings
	forest_wavelength = 65.0
	clearing_wavelength = 30.0
	moisture_wavelength = 85.0
	forest_frequency = 1.0 / forest_wavelength
	moisture_frequency = 1.0 / moisture_wavelength
	clearing_threshold = 0.45

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
	river_min_width = 1.35
	river_max_width = 3.85
	river_meander_strength = 0.18
	river_channel_depth = 0.22
	river_bank_width = 2.4
	river_bank_falloff = 1.6
	river_min_depth = 0.08
	river_max_depth = 0.45
	river_depth_response = 0.45
	river_width_response = 0.42
	hydrology_noise_enabled = true
	hydrology_noise_wavelength = 80.0
	hydrology_noise_frequency = 1.0 / hydrology_noise_wavelength
	hydrology_noise_strength = 0.25
	hydrology_noise_octaves = 2
	hydrology_noise_seed_offset = 707
	water_color_shallow = Color("#205485")
	water_color_medium = Color("#143c64")
	water_color_deep = Color("#0e253e")
	water_color_river = Color("#184674")
	water_color_lake = Color("#102e4d")
	water_roughness = 0.08
	water_transparency = 0.90


