class_name NecropolisEntranceProfile
extends Resource

## Parámetros de configuración ambiental para el entorno exterior de la entrada de Necrópolis.
## Define radios concéntricos de influencia, densidades y escalas sin lógica de generación acoplada.

@export_group("Radii")
@export var entrance_clear_radius: float = 4.5
@export var funeral_ground_radius: float = 14.0
@export var corruption_radius: float = 24.0
@export var transition_radius: float = 32.0

@export_group("Bone Patches")
@export var bone_patch_density: float = 0.45
@export var bone_patch_min_distance: float = 2.0
@export var bone_patch_scale_min: float = 0.8
@export var bone_patch_scale_max: float = 1.6

@export_group("Dead Trees")
@export var dead_tree_density: float = 0.25
@export var dead_tree_min_distance: float = 4.0
@export var dead_tree_scale_min: float = 2.5
@export var dead_tree_scale_max: float = 4.2

@export_group("Rocks and Atmosphere")
@export var dark_rock_density: float = 0.30
@export var normal_vegetation_multiplier: float = 0.15
@export var noise_frequency: float = 0.08
@export var ambient_darkening: float = 0.35
