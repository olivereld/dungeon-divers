class_name WallShowcaseGeometryConfig
extends Resource

## Configuración para Muros Rectos 3x2 de Mazmorra (Wall Showcase).
## Dimensiones: 3 cubos de largo (6.0m) x 2 cubos de alto (4.0m).

enum WallVariant {
	BARRED_WINDOW = 0,   ## Muro con arco y ventana enrejada de celda de hierro, alféizar y ladrillos
	CENTER_PILASTER = 1, ## Muro con pilar / pilastra central saliente con chaflanes a 45° y ladrillos
	FISSURE_BRICKS = 2,  ## Muro con grieta tallada diagonal, grupos de ladrillos y brotes de vegetación
	NICHE_ALCOVE = 3     ## Muro con nicho / hornacina arqueada empotrada, dovelas de ladrillo, repisa y vela votiva
}

@export var scale_mult: float = 1.0
@export var variant: WallVariant = WallVariant.BARRED_WINDOW
@export var width: float = 6.0                                  ## 3 cubos de 2.0m = 6.0m
@export var height: float = 4.0                                 ## 2 cubos de 2.0m = 4.0m
@export var depth: float = 0.45                                 ## Grosor de muro
@export var stone_color: Color = Color(0.66, 0.68, 0.72, 1.0)  ## Piedra principal de mazmorra
@export var stone_dark_color: Color = Color(0.52, 0.55, 0.60, 1.0) ## Ladrillos y molduras
@export var metal_color: Color = Color(0.32, 0.34, 0.38, 1.0)  ## Hierro forjado de rejas
@export var foliage_color: Color = Color(0.38, 0.62, 0.32, 1.0) ## Vegetación y brotes
@export var seed: int = 1337

func _init(
	p_variant: WallVariant = WallVariant.BARRED_WINDOW,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	variant = p_variant
	scale_mult = p_scale_mult
	seed = p_seed
