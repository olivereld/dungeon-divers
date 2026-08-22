class_name UrnGeometryConfig
extends Resource

## Configuración procedural para Urnas Funerarias, Vasijas y Frascos Canopos (Urns).
## Soporta estilos de suelo y de superficie (mesas / pedestales).

enum Style {
	BANDED_STONE_URN = 0,     ## Urna de piedra/barro con bandas horizontales y boca ancha (Estilo Ánfora)
	SKULL_RELIC_URN = 1,     ## Urna funeraria sellada con tapa biselada y relieve de cripta
	CEREMONIAL_PEDESTAL = 2, ## Urna monumental clásica sobre pedestal con fuste y copa moldurada
	CANOPIC_JAR = 3          ## Urna/vasija pequeña compacta de mesa o superficie (Tabletop / Surface)
}

@export var style: Style = Style.BANDED_STONE_URN
@export var scale_mult: float = 1.0
@export var radius: float = 0.28
@export var height: float = 0.68
@export var has_lid: bool = true
@export var num_sides: int = 12
@export var material_preset: int = 0
@export var seed: int = 1337

func _init(
	p_style: Style = Style.BANDED_STONE_URN,
	p_scale_mult: float = 1.0,
	p_has_lid: bool = true,
	p_num_sides: int = 12,
	p_material_preset: int = 0,
	p_seed: int = 1337
) -> void:
	style = p_style
	scale_mult = p_scale_mult
	has_lid = p_has_lid
	num_sides = p_num_sides
	material_preset = p_material_preset
	seed = p_seed
