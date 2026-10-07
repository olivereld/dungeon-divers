class_name FoliageProfile
extends Resource

## Parámetros de foliage para un bioma: densidad base, especies permitidas, límites de pendiente y ruido.

@export var base_density: float = 1.0
@export var species: Array = [] # Array[FoliageSpecies]
@export var min_height: float = 0.0
@export var max_height: float = 1.0
@export var water_clearance: float = 0.75
@export var max_slope: float = 28.0
@export var noise_frequency: float = 0.08
@export var wind_strength: float = 0.4
@export var wind_speed: float = 1.5

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

func get_species(species_id: StringName):
	for s in species:
		if s != null and "id" in s and s.id == species_id:
			return s
	return null
