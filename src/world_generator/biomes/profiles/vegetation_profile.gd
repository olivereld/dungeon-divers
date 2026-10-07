class_name VegetationProfile
extends Resource

## Parámetros de vegetación: densidades, espaciado Poisson y especies permitidas para un bioma.

@export var tree_density: float = 0.35
@export var shrub_density: float = 0.35
@export var min_tree_spacing: float = 3.2
@export var max_tree_slope: float = 22.0
@export var max_shrub_slope: float = 25.0
@export var tree_scale_min: float = 0.8
@export var tree_scale_max: float = 1.3
@export var shrub_scale_min: float = 0.5
@export var shrub_scale_max: float = 0.9
@export var allowed_species: Array = [&"conifer"]
