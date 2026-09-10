class_name WorldProfile
extends Resource

# Dimensions & Spatial Scale Contract (1 Godot unit = 1 meter)
@export_group("Dimensions & Spatial Scale")
@export var width: int = 256
@export var height: int = 256
@export_range(0.1, 10.0, 0.1) var cell_size: float = 1.0

# Terrain Physical Wavelengths & Amplitudes (meters)
@export_group("Terrain Physical Scale")
@export_range(20.0, 500.0, 5.0) var macro_wavelength: float = 140.0   # Horizontal span of large valleys/ridges (m)
@export_range(0.0, 40.0, 0.5) var macro_amplitude: float = 14.0       # Vertical elevation relief (m)
@export_range(10.0, 150.0, 2.0) var medium_wavelength: float = 45.0   # Horizontal span of hills/terraces (m)
@export_range(0.0, 20.0, 0.2) var medium_amplitude: float = 4.5       # Vertical elevation relief (m)
@export_range(2.0, 30.0, 0.5) var detail_wavelength: float = 10.0     # Horizontal span of ground ripples/roughness (m)
@export_range(0.0, 5.0, 0.05) var detail_amplitude: float = 0.6       # Vertical micro-relief (m)
@export var base_height: float = 2.0
@export_range(0.1, 5.0, 0.1) var height_scale: float = 1.0
@export_range(0.5, 3.0, 0.05) var relief_exponent: float = 1.1

# Legacy Frequency & Strength parameters for backwards compatibility
@export_range(0.001, 0.1, 0.001) var macro_frequency: float = 0.015
@export_range(0.0, 50.0, 0.5) var macro_strength: float = 12.0
@export_range(0.001, 0.2, 0.001) var medium_frequency: float = 0.045
@export_range(0.0, 20.0, 0.5) var medium_strength: float = 4.0
@export_range(0.01, 0.5, 0.01) var detail_frequency: float = 0.12
@export_range(0.0, 10.0, 0.1) var detail_strength: float = 1.2

# Domain Warp Physical Scale
@export_group("Domain Warp Physical Scale")
@export var warp_enabled: bool = true
@export_range(20.0, 300.0, 5.0) var warp_wavelength: float = 90.0    # Deformation wavelength in meters
@export_range(0.0, 50.0, 0.5) var warp_amplitude: float = 18.0       # Spatial coordinate displacement (m)
@export_range(1, 4, 1) var warp_octaves: int = 2
@export_range(0.001, 0.1, 0.001) var warp_frequency: float = 0.02
@export_range(0.0, 50.0, 0.5) var warp_strength: float = 15.0

# Ecology Physical Scale
@export_group("Ecology Physical Scale")
@export_range(20.0, 300.0, 5.0) var forest_wavelength: float = 65.0   # Forest stand spatial scale (m)
@export_range(10.0, 150.0, 2.0) var clearing_wavelength: float = 30.0 # Meadow / glade spatial scale (m)
@export_range(20.0, 300.0, 5.0) var moisture_wavelength: float = 85.0 # Moisture gradient scale (m)
@export_range(0.0, 1.0, 0.01) var clearing_threshold: float = 0.42
@export_range(0.001, 0.1, 0.001) var forest_frequency: float = 0.03
@export_range(0.001, 0.1, 0.001) var moisture_frequency: float = 0.025

# Vegetation
@export_group("Vegetation")
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.65
@export_range(0.0, 1.0, 0.01) var shrub_density: float = 0.40
@export_range(0.0, 1.0, 0.01) var rock_density: float = 0.15
@export_range(0.5, 10.0, 0.1) var min_tree_spacing: float = 2.2

# Navigation
@export_group("Navigation")
@export_range(5.0, 60.0, 1.0) var max_walkable_slope: float = 35.0  # degrees

# --- Helper Methods for Physical Scale & Wavelength Conversions ---
func get_world_extent() -> Vector2:
	return Vector2(float(width) * cell_size, float(height) * cell_size)

func get_macro_frequency() -> float:
	return 1.0 / maxf(macro_wavelength, 1.0) if macro_wavelength > 0.0 else macro_frequency

func get_macro_amplitude() -> float:
	return macro_amplitude if macro_amplitude > 0.0 else macro_strength

func get_medium_frequency() -> float:
	return 1.0 / maxf(medium_wavelength, 1.0) if medium_wavelength > 0.0 else medium_frequency

func get_medium_amplitude() -> float:
	return medium_amplitude if medium_amplitude > 0.0 else medium_strength

func get_detail_frequency() -> float:
	return 1.0 / maxf(detail_wavelength, 1.0) if detail_wavelength > 0.0 else detail_frequency

func get_detail_amplitude() -> float:
	return detail_amplitude if detail_amplitude > 0.0 else detail_strength

func get_warp_frequency() -> float:
	return 1.0 / maxf(warp_wavelength, 1.0) if warp_wavelength > 0.0 else warp_frequency

func get_warp_amplitude() -> float:
	return warp_amplitude if warp_amplitude > 0.0 else warp_strength

func get_forest_frequency() -> float:
	return 1.0 / maxf(forest_wavelength, 1.0) if forest_wavelength > 0.0 else forest_frequency

func get_moisture_frequency() -> float:
	return 1.0 / maxf(moisture_wavelength, 1.0) if moisture_wavelength > 0.0 else moisture_frequency

func get_hydrology_noise_frequency() -> float:
	return 1.0 / maxf(hydrology_noise_wavelength, 1.0) if hydrology_noise_wavelength > 0.0 else hydrology_noise_frequency

# Palette & Visuals (Pure Land Substrates - Zero Blue in Terrain Mesh)
@export_group("Palette & Visuals")
@export var terrain_loam_color: Color = Color("#3e3830")    # Suelo orgánico saturado / humus
@export var terrain_moss_color: Color = Color("#4a5338")    # Oliva frío / turbera y sotobosque
@export var terrain_grass_color: Color = Color("#3f4f34")   # Pradera boreal templada
@export var forest_floor_color: Color = Color("#25311e")    # Mantillo umbrío de coníferas
@export var terrain_rock_color: Color = Color("#464648")    # Granito frío de peñasco
@export var terrain_snow_color: Color = Color("#d8e2eb")    # Escarcha, permafrost y cimas

# Aliases for backward compatibility
@export var terrain_low_color: Color = Color("#3e3830")
@export var terrain_mid_color: Color = Color("#3f4f34")
@export var terrain_high_color: Color = Color("#d8e2eb")
@export var terrain_slope_color: Color = Color("#464648")
@export var clearing_color: Color = Color("#4a5338")
@export var forest_color: Color = Color("#25311e")

# Legacy Lab UI Palette Aliases
@export var color_deep_water: Color = Color("#1a3a5c")
@export var color_water: Color = Color("#2456a4")
@export var color_sand: Color = Color("#c8a96e")
@export var color_ground: Color = Color("#7a6548")
@export var color_grass: Color = Color("#4a8c3f")
@export var color_forest: Color = Color("#2d5a27")
@export var color_rock: Color = Color("#5a5a5a")
@export var color_snow: Color = Color("#dce8f0")

# Hydrology - General
@export_group("Hydrology - General")
@export var hydrology_enabled: bool = true

# Hydrology - Lakes
@export_group("Hydrology - Lakes")
@export_range(0.05, 0.60, 0.01) var lake_threshold: float = 0.22
@export_range(1, 50, 1) var lake_minimum_area: int = 4

# Hydrology - Rivers
@export_group("Hydrology - Rivers")
@export_range(0, 10, 1) var max_rivers: int = 3
@export_range(0.3, 0.95, 0.05) var river_source_min_height: float = 0.65
@export_range(1.0, 30.0, 0.5) var river_source_min_slope: float = 4.0
@export_range(5.0, 60.0, 1.0) var min_river_length: float = 12.0
@export_range(30.0, 300.0, 5.0) var max_river_length: float = 180.0
@export_range(50, 600, 10) var river_max_steps: int = 250
@export_range(0.3, 3.0, 0.1) var river_min_width: float = 0.8
@export_range(0.8, 6.0, 0.1) var river_max_width: float = 2.4
@export_range(0.0, 1.0, 0.02) var river_meander_strength: float = 0.18
@export_range(0.05, 0.80, 0.02) var river_channel_depth: float = 0.20
@export_range(0.8, 6.0, 0.1) var river_bank_width: float = 2.4
@export_range(0.5, 4.0, 0.1) var river_bank_falloff: float = 1.6
@export_range(0.05, 2.0, 0.02) var river_min_depth: float = 0.08
@export_range(0.1, 5.0, 0.05) var river_max_depth: float = 0.50
@export_range(0.2, 1.0, 0.05) var river_depth_response: float = 0.45
@export_range(0.2, 1.0, 0.05) var river_width_response: float = 0.42

# Hydrology - Noise Field (Channel Preference & Meanders)
@export_group("Hydrology - Noise Field")
@export var hydrology_noise_enabled: bool = true
@export_range(20.0, 300.0, 5.0) var hydrology_noise_wavelength: float = 80.0  # Meander preference wavelength (m)
@export_range(0.001, 0.1, 0.001) var hydrology_noise_frequency: float = 0.02
@export_range(0.0, 1.0, 0.05) var hydrology_noise_strength: float = 0.25
@export_range(1, 4, 1) var hydrology_noise_octaves: int = 2
@export var hydrology_noise_seed_offset: int = 707

# Hydrology - Water Visuals
@export_group("Hydrology - Water Visuals")
@export var water_color_shallow: Color = Color("#2a68a8")
@export var water_color_medium: Color = Color("#1e4e82")
@export var water_color_deep: Color = Color("#143254")
@export var water_color_river: Color = Color("#2d74b8")
@export var water_color_lake: Color = Color("#193e68")
@export_range(0.0, 1.0, 0.02) var water_roughness: float = 0.08
@export_range(0.1, 1.0, 0.05) var water_transparency: float = 0.85

