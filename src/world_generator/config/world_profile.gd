class_name WorldProfile
extends RefCounted

# Dimensions
var width: int = 128
var height: int = 128
var cell_size: float = 1.0

# Terrain Noise
var macro_frequency: float = 0.015
var macro_strength: float = 12.0
var medium_frequency: float = 0.045
var medium_strength: float = 4.0
var detail_frequency: float = 0.12
var detail_strength: float = 1.2
var base_height: float = 2.0
var height_scale: float = 1.0

# Domain Warp
var warp_enabled: bool = true
var warp_frequency: float = 0.02
var warp_strength: float = 15.0

# Ecology
var forest_frequency: float = 0.03
var clearing_threshold: float = 0.42
var moisture_frequency: float = 0.025

# Vegetation
var tree_density: float = 0.65
var shrub_density: float = 0.40
var rock_density: float = 0.15
var min_tree_spacing: float = 2.2

# Navigation
var max_walkable_slope: float = 35.0  # degrees
