class_name TableGeometryConfig
extends Resource

## Configuración procedural para Mesas de Mazmorra / Taberna (Table).

enum TableStyle {
	LONG_BANQUET = 0,   ## Mesa larga de banquete (~2.40m) con caballetes A-frame y viga longitudinal
	ROUND_TAVERN = 1,   ## Mesa redonda (~1.15m) con fuste central, base en cruz y aro de hierro
	STOUT_SQUARE = 2    ## Mesa robusta (~1.60m) con 4 patas acampanadas y botas de hierro
}

@export var scale_mult: float = 1.0
@export var style: TableStyle = TableStyle.LONG_BANQUET
@export var table_height: float = 0.76                          ## Altura ergonómica estándar de la mesa
@export var plank_thickness: float = 0.08                       ## Grosor de los tablones del tablero
@export var wood_color: Color = Color(0.74, 0.46, 0.20, 1.0)   ## Tono marrón cálido homogéneo para tablero y patas
@export var wood_dark_color: Color = Color(0.58, 0.34, 0.16, 1.0) ## Vigas estructurales secundarias
@export var metal_color: Color = Color(0.38, 0.40, 0.44, 1.0)  ## Gris oscuro metálico de hierro forjado
@export var seed: int = 1337

func _init(
	p_style: TableStyle = TableStyle.LONG_BANQUET,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	seed = p_seed
