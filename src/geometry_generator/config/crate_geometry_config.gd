class_name CrateGeometryConfig
extends Resource

## Configuración procedural para la Caja de Madera Estilizada (Wooden Crate).

enum DiagonalStyle {
	NONE = 0,        ## Sin cruceta diagonal
	SINGLE_Z = 1,    ## Refuerzo diagonal simple en Z / N (como en la referencia)
	CROSS_X = 2      ## Refuerzo en aspa (X)
}

@export var scale_mult: float = 1.0
@export var crate_size: Vector3 = Vector3(0.85, 0.85, 0.85) ## Dimensiones exteriores de la caja
@export var beam_width: float = 0.095                       ## Anchura de los listones perimetrales
@export var beam_depth: float = 0.035                       ## Relieve exterior del marco
@export var corner_cap_size: float = 0.10                   ## Tamaño de los herrajes metálicos en las 8 esquinas
@export var diagonal_style: DiagonalStyle = DiagonalStyle.SINGLE_Z
@export var plank_count_per_face: int = 3                   ## Número de tablas interiores por cara
@export var panel_wood_color: Color = Color(0.56, 0.35, 0.14, 1.0) ## Madera oscura de los tablones de fondo
@export var frame_wood_color: Color = Color(0.80, 0.52, 0.20, 1.0) ## Madera más clara de las vigas y diagonales
@export var iron_color: Color = Color(0.26, 0.28, 0.32, 1.0)       ## Hierro forjado de las cantoneras
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_diagonal_style: DiagonalStyle = DiagonalStyle.SINGLE_Z,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	diagonal_style = p_diagonal_style
	seed = p_seed
