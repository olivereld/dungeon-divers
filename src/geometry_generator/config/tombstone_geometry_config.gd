class_name TombstoneGeometryConfig
extends Resource

## Configuración procedural para Lápidas de Piedra (Tombstone).

enum TombstoneStyle {
	CLASSIC_ARCH = 0,  ## Lápida arqueada tradicional con marco y cruz en relieve
	CELTIC_CROSS = 1,  ## Cruz celta / gótica monumental
	BROKEN_SLAB = 2    ## Lápida rota / fracturada en el suelo
}

@export var scale_mult: float = 1.0
@export var style: TombstoneStyle = TombstoneStyle.CLASSIC_ARCH
@export var width: float = 0.52                            ## Anchura de la estela
@export var depth: float = 0.16                            ## Grosor de la estela
@export var height: float = 0.85                           ## Altura total
@export var base_width: float = 0.66                       ## Anchura del zócalo base
@export var base_depth: float = 0.36                       ## Profundidad del zócalo base
@export var base_height: float = 0.08                      ## Altura del zócalo base
@export var stone_color: Color = Color(0.58, 0.59, 0.57, 1.0)       ## Piedra gris de cementerio
@export var stone_trim_color: Color = Color(0.68, 0.70, 0.67, 1.0)  ## Molduras y relieves de cruz
@export var seed: int = 1337

func _init(
	p_style: TombstoneStyle = TombstoneStyle.CLASSIC_ARCH,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	seed = p_seed
