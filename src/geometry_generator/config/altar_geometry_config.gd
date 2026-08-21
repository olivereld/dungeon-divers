class_name AltarGeometryConfig
extends Resource

## Configuración procedural para el Altar de Piedra de Mazmorra (Stone Altar).

enum AltarSize {
	COMPACT = 0,    ## Altar compacto (~1.20m de largo)
	STANDARD = 1,   ## Altar estándar (~1.80m de largo)
	MONUMENTAL = 2  ## Gran altar ceremonial (~2.40m de largo)
}

@export var scale_mult: float = 1.0
@export var size_preset: AltarSize = AltarSize.STANDARD
@export var length: float = 1.80                           ## Longitud del altar (eje X)
@export var depth: float = 0.85                            ## Profundidad del altar (eje Z)
@export var height: float = 0.82                           ## Altura total estándar
@export var slab_thickness: float = 0.14                   ## Grosor de la losa superior
@export var slab_overhang: float = 0.06                    ## Vuelo/saliente de la mesa superior
@export var pilaster_width: float = 0.16                   ## Anchura de las 4 pilastras de esquina
@export var stone_body_color: Color = Color(0.64, 0.61, 0.55, 1.0) ## Piedra caliza del cuerpo y paneles
@export var stone_trim_color: Color = Color(0.74, 0.71, 0.65, 1.0) ## Piedra clara de la losa y molduras
@export var seed: int = 1337

func _init(
	p_size_preset: AltarSize = AltarSize.STANDARD,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	size_preset = p_size_preset
	scale_mult = p_scale_mult
	seed = p_seed
	_apply_preset()

func _apply_preset() -> void:
	match size_preset:
		AltarSize.COMPACT:
			length = 1.25
			depth = 0.80
		AltarSize.STANDARD:
			length = 1.80
			depth = 0.85
		AltarSize.MONUMENTAL:
			length = 2.40
			depth = 0.90
