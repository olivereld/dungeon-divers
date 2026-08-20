class_name WallGeometryConfig
extends Resource

## Parámetros estructurales y dimensiones geométricas puras para la generación de muros.
## No incluye parámetros de colisión ni decoración superficial de ladrillos.

@export_group("Dimensiones Estructurales")
@export_range(0.5, 10.0, 0.1) var cube_size: float = 2.0
@export_range(1, 10, 1) var cubes_high: int = 2
@export_range(0.1, 2.0, 0.05) var wall_thickness: float = 0.38

@export_group("Perfil de Molduras (Trims a 45°)")
@export_range(0.2, 1.2, 0.02) var top_trim_height: float = 0.55
@export_range(0.04, 0.3, 0.01) var top_trim_slope_height: float = 0.12
@export_range(0.15, 1.0, 0.02) var bottom_trim_height: float = 0.40
@export_range(0.04, 0.3, 0.01) var bottom_trim_slope_height: float = 0.10
@export_range(0.02, 0.25, 0.01) var trim_overhang: float = 0.08

@export_group("Ingletes y Esquinas")
@export var max_miter_scale: float = 1.41421356 # Factor de inglete clampeado a sqrt(2) para suprimir picos

@export_group("Determinismo")
@export var seed: int = 1337

func get_total_height() -> float:
	return float(cubes_high) * cube_size

func get_wall_panel_height() -> float:
	var h: float = get_total_height() - top_trim_height - bottom_trim_height
	return maxf(h, 0.2)

func duplicate_config() -> WallGeometryConfig:
	var c := WallGeometryConfig.new()
	c.cube_size = cube_size
	c.cubes_high = cubes_high
	c.wall_thickness = wall_thickness
	c.top_trim_height = top_trim_height
	c.top_trim_slope_height = top_trim_slope_height
	c.bottom_trim_height = bottom_trim_height
	c.bottom_trim_slope_height = bottom_trim_slope_height
	c.trim_overhang = trim_overhang
	c.max_miter_scale = max_miter_scale
	c.seed = seed
	return c
