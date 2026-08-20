class_name WallMeshConfig
extends Resource

## Configuración para el generador procedural de paredes, esquinas y arcos estilizados (estilo Zelda / KayKit).
## Soporta:
## - Paredes rectas modulares (Wall)
## - Esquinas en L continuas de 90° (Corner)
## - Arcos de puerta estilizados (Arch / Doorway) con vano curvado y pilares
## - Distribución dinámica procedimental basada en ruido (Noise-Driven Brick Clusters)

enum PieceType {
	WALL,            ## Pared recta modular
	CORNER,          ## Esquina en L de 90 grados
	ARCH,            ## Arco de paso / portal con vano libre
	DOOR,            ## Hoja de puerta de madera estilizada con aldaba
	ARCH_WITH_DOOR,  ## Portal completo: Arco de piedra + Hoja de puerta integrada
	FLOOR_TILE,      ## Baldosa individual de suelo estilizada con losas biseladas
	FLOOR_GRID_3X3   ## Cuadrícula de suelo 3x3 para probar el tileado continuo
}

enum WallStyle {
	STYLIZED_CLUSTERS,
	FULL_MASONRY
}

@export_group("Tipo de Pieza")
@export var piece_type: PieceType = PieceType.WALL

@export_group("Alineación y GridMap")
## Centrar el origen en (0, 0, 0) para compatibilidad directa con GridMap de Godot
@export var centered_origin: bool = false

@export_group("Dimensiones de Puerta (Door Settings)")
## Ancho de la hoja de puerta
@export_range(0.5, 2.0, 0.02) var door_width: float = 1.04
## Altura total de la hoja de puerta
@export_range(1.0, 3.5, 0.05) var door_height: float = 2.40
## Grosor de la hoja de madera
@export_range(0.05, 0.3, 0.01) var door_thickness: float = 0.12
## Número de tablones verticales
@export_range(2, 6, 1) var door_plank_count: int = 3
## Profundidad / saliente de los travesaños horizontales
@export_range(0.01, 0.08, 0.005) var door_batten_depth: float = 0.035
## Radio exterior del anillo de aldaba
@export_range(0.04, 0.20, 0.01) var door_knocker_radius: float = 0.10

@export_group("Dimensiones de Pared")
## Tamaño de una celda/cubo en metros (2.0m para coincidir con dungeon divers)
@export_range(0.5, 10.0, 0.1) var cube_size: float = 2.0
## Altura de la pared en cubos (2 cubos = 4.0m si cube_size=2.0)
@export_range(1, 10, 1) var cubes_high: int = 2
## Longitud de la pared en cubos (para piezas rectas)
@export_range(1, 20, 1) var wall_length_cubes: int = 2
## Grosor del cuerpo central del muro
@export_range(0.1, 2.0, 0.05) var wall_thickness: float = 0.38

@export_group("Dimensiones de Arco (Arch Settings)")
## Ancho del vano libre del arco
@export_range(0.6, 1.8, 0.05) var arch_opening_width: float = 1.08
## Altura del vano libre del arco (hasta la cúspide)
@export_range(1.0, 3.5, 0.05) var arch_opening_height: float = 2.50
## Bisel/chaflán suave a lo largo del borde interior del arco
@export_range(0.01, 0.10, 0.005) var arch_inner_bevel: float = 0.040

@export_group("Perfil de Molduras (Trims con Chaflán a 45°)")
## Altura total de la moldura/cornisa superior
@export_range(0.2, 1.2, 0.02) var top_trim_height: float = 0.55
## Altura del chaflán/pendiente a 45° inferior de la cornisa
@export_range(0.04, 0.3, 0.01) var top_trim_slope_height: float = 0.12
## Altura total del zócalo/base inferior
@export_range(0.15, 1.0, 0.02) var bottom_trim_height: float = 0.40
## Altura del chaflán/pendiente a 45° superior del zócalo
@export_range(0.04, 0.3, 0.01) var bottom_trim_slope_height: float = 0.10
## Vuelo / saliente hacia afuera de las molduras
@export_range(0.02, 0.25, 0.01) var trim_overhang: float = 0.08

@export_group("Juntas en V (V-Notches)")
## Ancho de la ranura divisoria en V
@export_range(0.02, 0.15, 0.005) var notch_width: float = 0.065
## Profundidad de la ranura en V hacia el interior
@export_range(0.01, 0.10, 0.005) var notch_depth: float = 0.040

@export_group("Esquinas (Corner Settings)")
## Chaflán a 45° en el vértice exterior de la esquina
@export_range(0.02, 0.20, 0.01) var corner_outer_chamfer: float = 0.08
## Chaflán/suavizado en el pliegue interior de la esquina
@export_range(0.0, 0.10, 0.005) var corner_inner_chamfer: float = 0.03

@export_group("Ladrillos Estilizados y Procedural Noise")
@export var wall_style: WallStyle = WallStyle.STYLIZED_CLUSTERS
## Activar distribución orgánica gobernada por función de ruido Simplex
@export var use_noise_distribution: bool = true
## Densidad de cobertura de ladrillos (0.1 = pocos ladrillos, 1.0 = alta cobertura)
@export_range(0.1, 1.0, 0.05) var brick_density: float = 0.55
## Frecuencia espacial del ruido procedimental
@export_range(0.2, 3.0, 0.05) var noise_frequency: float = 0.85
## Ancho base de un ladrillo
@export_range(0.15, 1.0, 0.02) var brick_width: float = 0.42
## Altura de un ladrillo
@export_range(0.08, 0.5, 0.01) var brick_height: float = 0.18
## Variación orgánica de tamaño (ancho y alto)
@export_range(0.0, 0.5, 0.02) var brick_size_variance: float = 0.22
## Relieve hacia afuera del panel
@export_range(0.01, 0.15, 0.005) var brick_protrusion: float = 0.038
## Variación orgánica de profundidad/relieve
@export_range(0.0, 0.5, 0.05) var brick_depth_variance: float = 0.30
## Bisel/redondeo suave en los bordes de los ladrillos (*pillowed*)
@export_range(0.01, 0.06, 0.002) var pillowed_bevel: float = 0.028
## Variación de rotación sutil (tilt orgánico)
@export_range(0.0, 0.15, 0.01) var brick_jitter_rot: float = 0.04

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
	c.piece_type = piece_type
	c.centered_origin = centered_origin
	c.cube_size = cube_size
	c.cubes_high = cubes_high
	c.wall_length_cubes = wall_length_cubes
	c.wall_thickness = wall_thickness
	c.arch_opening_width = arch_opening_width
	c.arch_opening_height = arch_opening_height
	c.arch_inner_bevel = arch_inner_bevel
	c.top_trim_height = top_trim_height
	c.top_trim_slope_height = top_trim_slope_height
	c.bottom_trim_height = bottom_trim_height
	c.bottom_trim_slope_height = bottom_trim_slope_height
	c.trim_overhang = trim_overhang
	c.notch_width = notch_width
	c.notch_depth = notch_depth
	c.corner_outer_chamfer = corner_outer_chamfer
	c.corner_inner_chamfer = corner_inner_chamfer
	c.wall_style = wall_style
	c.use_noise_distribution = use_noise_distribution
	c.brick_density = brick_density
	c.noise_frequency = noise_frequency
	c.brick_width = brick_width
	c.brick_height = brick_height
	c.brick_size_variance = brick_size_variance
	c.brick_protrusion = brick_protrusion
	c.brick_depth_variance = brick_depth_variance
	c.pillowed_bevel = pillowed_bevel
	c.brick_jitter_rot = brick_jitter_rot
	c.seed = seed
	return c
