class_name BarrelGeometryConfig
extends Resource

## Configuración procedural para el Barril de Madera Estilizado (Barrel).

@export var scale_mult: float = 1.0
@export var height: float = 0.92                   ## Altura total del barril
@export var rim_radius: float = 0.28               ## Radio en las tapas superior e inferior
@export var belly_radius: float = 0.36             ## Radio máximo en la panza central
@export var stave_count: int = 12                  ## Número de duelas/tablas perimetrales
@export var hoop_count: int = 2                    ## Número de zunchos/aros metálicos (2 o 4)
@export var hoop_width: float = 0.065              ## Anchura vertical de los aros de hierro
@export var hoop_thickness: float = 0.014          ## Grosor radial de los aros
@export var wood_color: Color = Color(0.72, 0.44, 0.16, 1.0) ## Madera de roble/pino miel estilizada
@export var iron_color: Color = Color(0.28, 0.30, 0.34, 1.0) ## Hierro forjado de los zunchos
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_stave_count: int = 12,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	stave_count = p_stave_count
	seed = p_seed
