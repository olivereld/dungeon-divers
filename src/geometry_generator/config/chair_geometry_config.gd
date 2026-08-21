class_name ChairGeometryConfig
extends Resource

## Configuración procedural para Sillas y Taburetes de Mazmorra / Taberna (Chair).

enum ChairStyle {
	TAVERN_STOOL = 0,    ## Taburete redondo (~0.50m) con asiento circular y patas inclinadas
	GOTHIC_HIGHBACK = 1, ## Silla gótica de respaldo alto (~1.15m) con arco ojival y barrotes
	TAVERN_ARMCHAIR = 2  ## Sillón de taberna (~1.05m) con reposabrazos y respaldo de tablones
}

@export var scale_mult: float = 1.0
@export var style: ChairStyle = ChairStyle.TAVERN_STOOL
@export var seat_height: float = 0.48                           ## Altura del asiento sobre el suelo
@export var seat_thickness: float = 0.06                        ## Grosor del asiento
@export var wood_color: Color = Color(0.74, 0.46, 0.20, 1.0)   ## Madera de roble cálido uniforme
@export var wood_trim_color: Color = Color(0.58, 0.34, 0.16, 1.0) ## Molduras y refuerzos
@export var metal_color: Color = Color(0.38, 0.40, 0.44, 1.0)  ## Pernos de forja
@export var seed: int = 1337

func _init(
	p_style: ChairStyle = ChairStyle.TAVERN_STOOL,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	seed = p_seed
