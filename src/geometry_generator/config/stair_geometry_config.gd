class_name StairGeometryConfig
extends Resource

## Configuración paramétrica para la generación de tramos de escalera estilizados con pretiles y zócalos.

@export_group("Dimensiones Principales")
@export var tile_size: float = 2.0
@export var stair_rise: float = 1.8
@export var num_steps: int = 8
@export var is_downward: bool = false

@export_group("Pretiles y Zócalos")
@export var stringer_width: float = 0.22
@export var stringer_height: float = 0.40
@export var bottom_trim_height: float = 0.22
@export var bottom_trim_slope_height: float = 0.08
@export var trim_overhang: float = 0.04

@export_group("Detalles de Peldaños")
@export var step_bevel: float = 0.018
@export var step_nose_overhang: float = 0.020

@export_group("Mampostería y Relieve Lateral")
@export var side_bricks_enabled: bool = true
@export var side_brick_density: float = 0.70
@export var seed: int = 1337

func duplicate_config():
	var c = get_script().new()
	c.tile_size = tile_size
	c.stair_rise = stair_rise
	c.num_steps = num_steps
	c.is_downward = is_downward
	c.stringer_width = stringer_width
	c.stringer_height = stringer_height
	c.bottom_trim_height = bottom_trim_height
	c.bottom_trim_slope_height = bottom_trim_slope_height
	c.trim_overhang = trim_overhang
	c.step_bevel = step_bevel
	c.step_nose_overhang = step_nose_overhang
	c.side_bricks_enabled = side_bricks_enabled
	c.side_brick_density = side_brick_density
	c.seed = seed
	return c
