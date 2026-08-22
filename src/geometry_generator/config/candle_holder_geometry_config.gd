class_name CandleHolderGeometryConfig
extends Resource

## Configuración procedural para el Candelabro / Candelero Gótico (Candle Holder).

@export var scale_mult: float = 1.0
@export var base_radius: float = 0.22
@export var arm_span: float = 0.24
@export var total_height: float = 0.85
@export var num_sides: int = 8
@export var candle_count: int = 3
@export var wax_color: Color = Color(0.93, 0.90, 0.82, 1.0) # Blanco marfil / cera cálida
@export var flame_color: Color = Color(1.0, 0.70, 0.20, 1.0) # Color de la llama
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_num_sides: int = 8,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	num_sides = p_num_sides
	seed = p_seed
