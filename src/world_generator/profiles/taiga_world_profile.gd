class_name TaigaWorldProfile
extends WorldProfile

func _init() -> void:
	width = 64
	height = 64
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
	vegetation_bank_clearance = 1.5
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
	lake_merge_distance = 4.0
	max_rivers = 3
	river_source_min_height = 0.65
	river_source_min_slope = 4.0
	min_river_length = 12.0
	max_river_length = 180.0
	river_max_steps = 250
	river_min_width = 3.0
	river_max_width = 8.0
	river_min_cells = 3
	river_max_cells = 8
	river_meander_strength = 0.18
	river_channel_depth = 0.22
	river_min_depth = 0.08
	river_max_depth = 0.45
	river_freeboard = 0.08
	shoreline_bank_bevel = 0.18
	shoreline_offset = 0.0
	river_depth_response = 0.45
	river_width_response = 0.42
	water_field_resolution = 224
	contour_simplification_tolerance = 0.05
	minimum_contour_edge = 0.03
	minimum_polygon_area = 0.20
	hydrology_noise_enabled = true
	hydrology_noise_wavelength = 80.0
	hydrology_noise_frequency = 1.0 / hydrology_noise_wavelength
	hydrology_noise_strength = 0.25
	hydrology_noise_octaves = 2
	hydrology_noise_seed_offset = 707
	water_color_shallow = Color("#22b8c6")
	water_color_medium = Color("#12729a")
	water_color_deep = Color("#073b5e")
	water_color_river = Color("#1cb0be")
	water_color_lake = Color("#073b5e")
	water_roughness = 0.08
	water_transparency = 0.90

	# Texturas de Ribera y Lecho
	shoreline_rock_offset = 0.35
	shoreline_rock_fade = 0.25
	shoreline_sand_offset = -0.55
	shoreline_sand_fade = 0.35
	riverbed_uv_scale = 0.35
	sand_uv_scale = 0.40
	grass_uv_scale = 0.35
	forest_grass_uv_scale = 0.35
	forest_dirt_uv_scale = 0.35


## Configura la paleta cromática completa y los tintes de vegetación del bosque otoñal
func apply_autumn_preset() -> void:
	# Terreno otoñal (Taiga Otoñal)
	terrain_loam_color = Color("#422b1e")   # Humus marrón otoñal
	terrain_moss_color = Color("#736835")   # Musgo seco / ocre dorado
	terrain_grass_color = Color("#5a5428")  # Hierba otoñal ámbar/mostaza
	forest_floor_color = Color("#3d2817")   # Mantillo umbrío de acículas
	terrain_rock_color = Color("#4e4844")   # Granito cálido
	terrain_snow_color = Color("#e0dcd4")   # Cumbres pálidas / escarcha ligera

	terrain_low_color = terrain_loam_color
	terrain_mid_color = terrain_grass_color
	terrain_high_color = terrain_snow_color
	terrain_slope_color = terrain_rock_color
	clearing_color = terrain_moss_color
	forest_color = forest_floor_color

	color_ground = terrain_loam_color
	color_grass = terrain_grass_color
	color_forest = forest_floor_color
	color_rock = terrain_rock_color
	color_snow = terrain_snow_color
	color_sand = terrain_moss_color

	# Agua otoñal (tonos profundos reflejando cielo y bosque otoñal)
	water_color_shallow = Color("#355568")
	water_color_medium = Color("#22384a")
	water_color_deep = Color("#182836")
	water_color_river = Color("#2c4c5e")
	water_color_lake = Color("#182836")

	color_water = water_color_shallow
	color_deep_water = water_color_deep

	# Variantes de tinte cálido para follaje de árboles y arbustos
	foliage_tint = Color("#d97706") # Ámbar otoñal base
	foliage_tint_variants = [
		Color("#d97706"), # Ámbar dorado
		Color("#ea580c"), # Naranja fuego
		Color("#ca8a04"), # Amarillo ocre
		Color("#a16207"), # Castaño dorado
		Color("#654d24"), # Oliva otoñal
	]
