class_name BookshelfGeometryConfig
extends Resource

## Configuración procedural para Librerías y Estanterías de Mazmorra (Bookshelf).

enum BookshelfStyle {
	STANDARD_EMPTY = 0,   ## Estantería de 4 niveles vacía
	STANDARD_FILLED = 1,  ## Estantería con hileras de libros, tomos inclinados y pilas horizontales
	GOTHIC_ARCHED = 2     ## Estantería gótica con arco superior, copete y libros arcanos
}

@export var scale_mult: float = 1.0
@export var style: BookshelfStyle = BookshelfStyle.STANDARD_FILLED
@export var width: float = 1.10                                 ## Anchura total de la estantería
@export var height: float = 1.90                                ## Altura total
@export var depth: float = 0.38                                 ## Profundidad del mueble
@export var shelf_count: int = 4                                ## Número de estantes
@export var wood_color: Color = Color(0.68, 0.44, 0.22, 1.0)    ## Madera de roble cálido uniforme
@export var wood_dark_color: Color = Color(0.52, 0.30, 0.14, 1.0) ## Molduras de cornisa y zócalo
@export var seed: int = 1337

func _init(
	p_style: BookshelfStyle = BookshelfStyle.STANDARD_FILLED,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	seed = p_seed
