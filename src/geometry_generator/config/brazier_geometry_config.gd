class_name BrazierGeometryConfig
extends Resource

## Configuración de parámetros procedurales para el Brasero Gótico de Pie (Brazier).

@export var scale_mult: float = 1.0
@export var base_radius: float = 0.28
@export var shaft_radius: float = 0.12
@export var cup_top_radius: float = 0.29
@export var total_height: float = 1.15
@export var num_sides: int = 8
@export var coal_chunks_count: int = 14
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_num_sides: int = 8,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	num_sides = p_num_sides
	seed = p_seed
