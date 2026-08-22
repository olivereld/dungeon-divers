class_name BenchGeometryConfig
extends Resource

## Configuración procedural para Bancas y Banquetas de Mazmorra (Bench).
## Diseñadas para múltiples personas en templos, criptas, tabernas y salas comunales.

enum BenchStyle {
	CHURCH_PEW = 0,    ## Banco de iglesia / templo con paneles laterales altos, balaustres y respaldo
	STONE_ORIOR = 1,   ## Banco de piedra esculpida con patas de voluta/scroll y losa pesada
	TAVERN_BENCH = 2,  ## Banco estilizado de taberna con respaldo arqueado, reposabrazos y cojines
	BACKLESS_BENCH = 3 ## Banqueta corrida rústica sin respaldo con travesaño de soporte
}

@export var scale_mult: float = 1.0
@export var style: BenchStyle = BenchStyle.CHURCH_PEW
@export var length: float = 1.40                            ## Longitud longitudinal (Eje X)
@export var depth: float = 0.50                             ## Profundidad del asiento (Eje Z)
@export var seat_height: float = 0.46                       ## Altura del asiento sobre el suelo
@export var seat_thickness: float = 0.05                    ## Grosor de la tabla/losa del asiento
@export var backrest_height: float = 0.54                   ## Altura del respaldo sobre el asiento

# Colores y Materiales
@export var wood_color: Color = Color(0.68, 0.44, 0.20, 1.0)       ## Madera principal (roble / nogal)
@export var wood_trim_color: Color = Color(0.50, 0.30, 0.14, 1.0)  ## Molduras, paneles y balaustres
@export var stone_color: Color = Color(0.62, 0.63, 0.65, 1.0)      ## Piedra de banco de cripta/templo
@export var stone_trim_color: Color = Color(0.74, 0.75, 0.78, 1.0) ## Relieves y molduras de piedra
@export var cushion_color: Color = Color(0.75, 0.72, 0.68, 1.0)    ## Cojines de tela acolchada
@export var metal_color: Color = Color(0.32, 0.34, 0.38, 1.0)      ## Pernos y herrajes de forja
@export var seed: int = 1337

func _init(
	p_style: BenchStyle = BenchStyle.CHURCH_PEW,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	seed = p_seed
