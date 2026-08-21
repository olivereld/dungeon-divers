class_name RubbleGeometryConfig
extends Resource

## Configuración procedural para el Derrumbe de Escombros (Rubble).

enum RubbleSize {
	SMALL = 0,   ## Montículo pequeño (~1.0m x 1.0m)
	MEDIUM = 1,  ## Derrumbe mediano (~1.5m x 1.5m)
	LARGE = 2    ## Gran colapso de muro/techo (~2.0m x 2.0m)
}

@export var scale_mult: float = 1.0
@export var size_preset: RubbleSize = RubbleSize.MEDIUM
@export var block_count: int = 18                           ## Cantidad de bloques y sillares caídos
@export var pebble_count: int = 24                          ## Cantidad de fragmentos y guijarros pequeños
@export var mound_radius: float = 0.85                      ## Radio del sustrato de polvo/grava base
@export var mound_height: float = 0.18                      ## Altura máxima central del montículo
@export var include_props: bool = false                     ## Si incluye cajas/barriles aplastados entre los escombros
@export var primary_stone_color: Color = Color(0.52, 0.50, 0.47, 1.0)   ## Piedra gris de muro de mazmorra
@export var secondary_stone_color: Color = Color(0.62, 0.40, 0.30, 1.0) ## Ladrillo terracota / piedra contrastada
@export var gravel_color: Color = Color(0.38, 0.36, 0.34, 1.0)          ## Grava y polvo de escombros
@export var seed: int = 1337

func _init(
	p_size_preset: RubbleSize = RubbleSize.MEDIUM,
	p_include_props: bool = false,
	p_seed: int = 1337
) -> void:
	size_preset = p_size_preset
	include_props = p_include_props
	seed = p_seed
	_apply_preset()

func _apply_preset() -> void:
	match size_preset:
		RubbleSize.SMALL:
			block_count = 10
			pebble_count = 14
			mound_radius = 0.55
			mound_height = 0.12
		RubbleSize.MEDIUM:
			block_count = 18
			pebble_count = 24
			mound_radius = 0.85
			mound_height = 0.20
		RubbleSize.LARGE:
			block_count = 30
			pebble_count = 38
			mound_radius = 1.15
			mound_height = 0.32
