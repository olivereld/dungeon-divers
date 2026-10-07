class_name BiomeSelectionRule
extends Resource

## Regla de datos pura que determina cuándo corresponde seleccionar un bioma en base a
## temperatura, humedad y elevación normalizada [0.0, 1.0].

@export var biome_id: StringName = &"taiga"
@export var min_temperature: float = 0.0
@export var max_temperature: float = 1.0
@export var min_moisture: float = 0.0
@export var max_moisture: float = 1.0
@export var min_elevation: float = 0.0
@export var max_elevation: float = 1.0
@export var priority: int = 10

func _init(
	p_biome_id: StringName = &"taiga",
	p_min_temp: float = 0.0,
	p_max_temp: float = 1.0,
	p_min_moist: float = 0.0,
	p_max_moist: float = 1.0,
	p_min_elev: float = 0.0,
	p_max_elev: float = 1.0,
	p_priority: int = 10
) -> void:
	biome_id = p_biome_id
	min_temperature = p_min_temp
	max_temperature = p_max_temp
	min_moisture = p_min_moist
	max_moisture = p_max_moist
	min_elevation = p_min_elev
	max_elevation = p_max_elev
	priority = p_priority

func matches(temperature: float, moisture: float, elevation: float) -> bool:
	return temperature >= min_temperature and temperature <= max_temperature and \
		moisture >= min_moisture and moisture <= max_moisture and \
		elevation >= min_elevation and elevation <= max_elevation
