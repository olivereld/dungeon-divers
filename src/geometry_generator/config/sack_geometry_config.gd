class_name SackGeometryConfig
extends Resource

## Configuración procedural para el Saco de Arpillera / Tela Estilizado (Sack).

@export var scale_mult: float = 1.0
@export var height: float = 0.82                           ## Altura total del saco erguido
@export var base_radius: float = 0.26                      ## Radio del asentamiento en el suelo
@export var belly_radius: float = 0.33                     ## Radio máximo de la panza
@export var neck_radius: float = 0.10                      ## Radio del cuello fruncido
@export var crown_radius: float = 0.18                     ## Radio de la corona/boca superior de tela
@export var segments: int = 10                             ## Segmentos radiales
@export var fabric_color: Color = Color(0.72, 0.58, 0.40, 1.0) ## Tela de arpillera / yute cálido
@export var rope_color: Color = Color(0.42, 0.30, 0.18, 1.0)   ## Cuerda de cáñamo / atadura
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_segments: int = 10,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	segments = p_segments
	seed = p_seed
