class_name StairGeometryConfig
extends Resource

## Configuración paramétrica para la generación de tramos de escalera de piedra y pretiles.

@export_group("Dimensiones de la Escalera")
@export var tile_size: float = 2.0
@export var stair_rise: float = 1.8
@export var num_steps: int = 8
@export var is_downward: bool = false
@export var stringer_width: float = 0.12
@export var stringer_height: float = 0.45
@export var seed: int = 1337

func duplicate_config():
	var c = get_script().new()
	c.tile_size = tile_size
	c.stair_rise = stair_rise
	c.num_steps = num_steps
	c.is_downward = is_downward
	c.stringer_width = stringer_width
	c.stringer_height = stringer_height
	c.seed = seed
	return c
