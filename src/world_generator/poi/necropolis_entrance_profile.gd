class_name NecropolisEntranceProfile
extends Resource

## Parámetros de configuración ambiental para el entorno exterior de la entrada de Necrópolis.
## Define radios concéntricos de influencia, densidades y magnitudes físicas semánticas.

@export_group("Radii")
@export var entrance_clear_radius: float = 4.5
@export var funeral_ground_radius: float = 12.0
@export var corruption_radius: float = 22.0
@export var transition_radius: float = 40.0

@export_group("Bone Patches")
@export var bone_patch_density: float = 0.45
@export var bone_patch_min_distance: float = 2.0
@export var bone_patch_scale_min: float = 0.7
@export var bone_patch_scale_max: float = 1.15

@export_group("Dead Trees")
@export var dead_tree_density: float = 0.25
@export var dead_tree_min_distance: float = 4.0
@export var dead_tree_height_min: float = 4.8
@export var dead_tree_height_max: float = 7.0
@export var dead_tree_scale_min: float = 1.8
@export var dead_tree_scale_max: float = 2.8

@export_group("Fallen Wood")
@export var stump_density: float = 0.12
@export var stump_height_min: float = 0.35
@export var stump_height_max: float = 0.80
@export var log_density: float = 0.10
@export var log_length_min: float = 1.5
@export var log_length_max: float = 4.0
@export var fallen_wood_min_distance: float = 2.0

@export_group("Fungal Accents")
@export var mushroom_density: float = 0.08
@export var mushroom_scale_min: float = 0.65
@export var mushroom_scale_max: float = 1.15
@export var mushroom_cluster_radius: float = 1.5

@export_group("Rocks and Atmosphere")
@export var dark_rock_density: float = 0.30
@export var normal_vegetation_multiplier: float = 0.15
@export var noise_frequency: float = 0.08
@export var ambient_darkening: float = 0.35
