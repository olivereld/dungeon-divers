class_name ArchGeometryConfig
extends Resource

## Configuración paramétrica para la generación de arcos de mampostería estilizados.

@export_group("Dimensiones Principales")
@export var width: float = 2.0
@export var height: float = 4.0
@export var wall_thickness: float = 0.40
@export var trim_overhang: float = 0.04
@export var bottom_trim_height: float = 0.22
@export var bottom_trim_slope_height: float = 0.08
@export var top_trim_height: float = 0.40
@export var top_trim_slope_height: float = 0.12

@export_group("Dimensiones de la Abertura")
@export var opening_width: float = 1.06
@export var opening_height: float = 2.50
@export var arch_inner_bevel: float = 0.02
@export var notch_width: float = 0.065
@export var notch_depth: float = 0.040

@export_group("Decoración de Ladrillos")
@export var brick_density: float = 0.65
@export var brick_width: float = 0.24
@export var brick_height: float = 0.12
@export var noise_frequency: float = 0.15
@export var seed: int = 1337
@export var centered_origin: bool = true

func duplicate_config():
	var c = get_script().new()
	c.width = width
	c.height = height
	c.wall_thickness = wall_thickness
	c.trim_overhang = trim_overhang
	c.bottom_trim_height = bottom_trim_height
	c.bottom_trim_slope_height = bottom_trim_slope_height
	c.top_trim_height = top_trim_height
	c.top_trim_slope_height = top_trim_slope_height
	c.opening_width = opening_width
	c.opening_height = opening_height
	c.arch_inner_bevel = arch_inner_bevel
	c.notch_width = notch_width
	c.notch_depth = notch_depth
	c.brick_density = brick_density
	c.brick_width = brick_width
	c.brick_height = brick_height
	c.noise_frequency = noise_frequency
	c.seed = seed
	c.centered_origin = centered_origin
	return c
