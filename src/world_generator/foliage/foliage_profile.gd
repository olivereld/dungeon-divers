class_name FoliageProfile
extends Resource

## Parámetros de foliage para un bioma: densidad base, especies permitidas, límites de pendiente y ruido.

enum EcologicalZone {
	PLAINS = 0,       ## Planicie abierta: hierba abundante, muy pocos árboles
	FOREST_EDGE = 1,  ## Borde de bosque: transición entre planicie y arboleda
	OPEN_FOREST = 2,  ## Bosque abierto: árboles separados con claro visible
	DENSE_FOREST = 3, ## Bosque denso: clusters compactos de árboles y dosel sombreado
	CLEARING = 4      ## Claro forestal: espacio abierto deliberado dentro del bosque
}

@export var base_density: float = 1.0
@export var species: Array = [] # Array[FoliageSpecies]
@export var min_height: float = 0.0
@export var max_height: float = 1.0
@export var water_clearance: float = 0.75
@export var max_slope: float = 28.0
@export var noise_frequency: float = 0.08
@export var large_noise_frequency: float = 0.02
@export var fine_noise_frequency: float = 0.12
@export var canopy_influence_radius: float = 2.0
@export var canopy_attenuation_factor: float = 0.35
@export var clearing_threshold: float = 0.35
@export var zone_densities: Dictionary = {
	EcologicalZone.PLAINS: {"grass": 1.0, "shrub": 0.10, "tree": 0.02},
	EcologicalZone.FOREST_EDGE: {"grass": 0.80, "shrub": 0.25, "tree": 0.20},
	EcologicalZone.OPEN_FOREST: {"grass": 0.60, "shrub": 0.35, "tree": 0.40},
	EcologicalZone.DENSE_FOREST: {"grass": 0.40, "shrub": 0.45, "tree": 0.70},
	EcologicalZone.CLEARING: {"grass": 0.90, "shrub": 0.15, "tree": 0.05}
}
@export var wind_strength: float = 0.25
@export var wind_speed: float = 1.6

func _init(
	p_base_density: float = 1.0,
	p_species: Array = [],
	p_max_slope: float = 28.0,
	p_water_clearance: float = 0.75
) -> void:
	base_density = p_base_density
	species = p_species
	max_slope = p_max_slope
	water_clearance = p_water_clearance
	if zone_densities.is_empty():
		zone_densities = {
			EcologicalZone.PLAINS: {"grass": 1.0, "shrub": 0.10, "tree": 0.02},
			EcologicalZone.FOREST_EDGE: {"grass": 0.80, "shrub": 0.25, "tree": 0.20},
			EcologicalZone.OPEN_FOREST: {"grass": 0.60, "shrub": 0.35, "tree": 0.40},
			EcologicalZone.DENSE_FOREST: {"grass": 0.40, "shrub": 0.45, "tree": 0.70},
			EcologicalZone.CLEARING: {"grass": 0.90, "shrub": 0.15, "tree": 0.05}
		}

func get_species(species_id: StringName):
	for s in species:
		if s != null and "id" in s and s.id == species_id:
			return s
	return null
