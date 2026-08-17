class_name WallMeshConfig
extends Resource

## Configuración para el generador procedural de paredes estilizadas (estilo Low-Poly / Hand-crafted).
## Soporta pared de 2 cubos de alto con moldura superior, zócalo inferior,
## panel de muro liso y parches de ladrillos en relieve redondeados.

enum WallStyle {
	STYLIZED_CLUSTERS, ## Estilo referencia: panel liso con molduras y parches aislados de ladrillos redondeados
	FULL_MASONRY       ## Pared completa de mampostería tradicional
}

@export_group("Dimensiones de Pared")
## Tamaño de una celda/cubo en metros (2.0m para coincidir con el dungeon)
@export_range(0.5, 10.0, 0.1) var cube_size: float = 2.0
## Altura de la pared en cubos (2 cubos = 4.0m si cube_size=2.0)
@export_range(1, 10, 1) var cubes_high: int = 2
## Longitud de la pared en cubos (2 cubos = 4.0m)
@export_range(1, 20, 1) var wall_length_cubes: int = 2
## Grosor del cuerpo principal del muro
@export_range(0.1, 2.0, 0.05) var wall_thickness: float = 0.40

@export_group("Molduras (Trims)")
## Altura de la moldura/viga superior de piedra oscura
@export_range(0.1, 1.0, 0.02) var top_trim_height: float = 0.45
## Altura del zócalo/viga inferior de piedra oscura
@export_range(0.1, 1.0, 0.02) var bottom_trim_height: float = 0.35
## Saliente/voladizo de las molduras respecto a la pared
@export_range(0.0, 0.2, 0.01) var trim_overhang: float = 0.04
## Ancho de la ranura/junta vertical divisoria en las molduras
@export_range(0.01, 0.1, 0.005) var trim_notch_width: float = 0.035

@export_group("Ladrillos Estilizados en Relieve")
## Modo de pared
@export var wall_style: WallStyle = WallStyle.STYLIZED_CLUSTERS
## Ancho base de un ladrillo estilizado
@export_range(0.15, 1.0, 0.02) var brick_width: float = 0.42
## Altura de un ladrillo estilizado
@export_range(0.08, 0.5, 0.01) var brick_height: float = 0.18
## Cuánto sobresale el ladrillo hacia afuera del panel de pared
@export_range(0.01, 0.15, 0.005) var brick_protrusion: float = 0.035
## Bisel/redondeo suave en las aristas de los ladrillos (*pillowed corners*)
@export_range(0.01, 0.06, 0.002) var pillowed_bevel: float = 0.030
## Variación de rotación sutil de los ladrillos
@export var brick_jitter_rot: float = 0.03

@export_group("Semilla y Determinismo")
@export var seed: int = 1337

func get_total_height() -> float:
	return float(cubes_high) * cube_size

func get_total_length() -> float:
	return float(wall_length_cubes) * cube_size

func get_wall_panel_height() -> float:
	var h: float = get_total_height() - top_trim_height - bottom_trim_height
	return maxf(h, 0.2)

func duplicate_config() -> WallMeshConfig:
	var c := WallMeshConfig.new()
	c.cube_size = cube_size
	c.cubes_high = cubes_high
	c.wall_length_cubes = wall_length_cubes
	c.wall_thickness = wall_thickness
	c.top_trim_height = top_trim_height
	c.bottom_trim_height = bottom_trim_height
	c.trim_overhang = trim_overhang
	c.trim_notch_width = trim_notch_width
	c.wall_style = wall_style
	c.brick_width = brick_width
	c.brick_height = brick_height
	c.brick_protrusion = brick_protrusion
	c.pillowed_bevel = pillowed_bevel
	c.brick_jitter_rot = brick_jitter_rot
	c.seed = seed
	return c
