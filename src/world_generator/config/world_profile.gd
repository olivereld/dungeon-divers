class_name WorldProfile
extends Resource

# Dimensions
@export_group("Dimensions")
@export var width: int = 128
@export var height: int = 128
@export_range(0.1, 10.0, 0.1) var cell_size: float = 1.0

# Terrain Noise
@export_group("Terrain Noise")
@export_range(0.001, 0.1, 0.001) var macro_frequency: float = 0.015
@export_range(0.0, 50.0, 0.5) var macro_strength: float = 12.0
@export_range(0.001, 0.2, 0.001) var medium_frequency: float = 0.045
@export_range(0.0, 20.0, 0.5) var medium_strength: float = 4.0
@export_range(0.01, 0.5, 0.01) var detail_frequency: float = 0.12
@export_range(0.0, 10.0, 0.1) var detail_strength: float = 1.2
@export var base_height: float = 2.0
@export_range(0.1, 5.0, 0.1) var height_scale: float = 1.0
@export_range(0.5, 3.0, 0.05) var relief_exponent: float = 1.1

# Domain Warp
@export_group("Domain Warp")
@export var warp_enabled: bool = true
@export_range(0.001, 0.1, 0.001) var warp_frequency: float = 0.02
@export_range(0.0, 50.0, 0.5) var warp_strength: float = 15.0
@export_range(1, 4, 1) var warp_octaves: int = 2

# Ecology
@export_group("Ecology")
@export_range(0.001, 0.1, 0.001) var forest_frequency: float = 0.03
@export_range(0.0, 1.0, 0.01) var clearing_threshold: float = 0.42
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

# Palette & Visuals
@export_group("Palette & Visuals")
@export var terrain_low_color: Color = Color(0.20, 0.27, 0.16)
@export var terrain_mid_color: Color = Color(0.27, 0.35, 0.21)
@export var terrain_high_color: Color = Color(0.40, 0.42, 0.35)
@export var terrain_slope_color: Color = Color(0.36, 0.35, 0.33)
@export var clearing_color: Color = Color(0.36, 0.38, 0.20)
@export var forest_color: Color = Color(0.15, 0.22, 0.13)

# 8-Zone Elevation & Terrain Palette (Hex matching Lab UI)
@export var color_deep_water: Color = Color("#1a3a5c")
@export var color_water: Color = Color("#2456a4")
@export var color_sand: Color = Color("#c8a96e")
@export var color_ground: Color = Color("#7a6548")
@export var color_grass: Color = Color("#4a8c3f")
@export var color_forest: Color = Color("#2d5a27")
@export var color_rock: Color = Color("#5a5a5a")
@export var color_snow: Color = Color("#dce8f0")
