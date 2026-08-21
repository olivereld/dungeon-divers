class_name ChestGeometryConfig
extends Resource

## Configuración procedural para el Cofre de Mazmorra Estilizado (Chest).

@export var scale_mult: float = 1.0
@export var width: float = 0.80                           ## Anchura del cofre (eje X)
@export var depth: float = 0.54                           ## Profundidad del cofre (eje Z)
@export var base_height: float = 0.40                     ## Altura del cajón inferior
@export var lid_height: float = 0.24                      ## Altura de la bóveda de la tapa
@export var wall_thickness: float = 0.038                 ## Grosor de las paredes
@export var rim_width: float = 0.045                      ## Anchura de los marcos metálicos/refuerzos
@export var panel_wood_color: Color = Color(0.55, 0.33, 0.13, 1.0) ## Madera oscura de paneles interiores y exteriores
@export var frame_wood_color: Color = Color(0.78, 0.50, 0.18, 1.0) ## Madera cálida de los marcos
@export var metal_color: Color = Color(0.30, 0.33, 0.38, 1.0)      ## Hierro forjado / herrajes y cerradura
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	scale_mult = p_scale_mult
	seed = p_seed
