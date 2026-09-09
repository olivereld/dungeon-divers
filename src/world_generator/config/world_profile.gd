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
