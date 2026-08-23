class_name FixtureBudgetRule
extends Resource

## Regla declarativa de colocación, densidad y presupuesto para fixtures arquitectónicos.
##
## AUTORIDAD DE CANTIDAD Y DENSIDAD:
## Esta clase es la única autoridad que gobierna cuántas luminarias se colocan en una habitación:
## - `min_count`: Garantía mínima de colocación para este rol/tipo.
## - `max_count`: Límite superior permitido dentro del presupuesto energético.
## - `affinity`: Rol espacial (FOCAL_COMPANION acompañando props clave, PERIMETER en muros, FREE ambiental).
##
## Los pesos (`weight`) en `FixturePaletteEntry` solo resuelven QUÉ estilo elegir cuando hay múltiples opciones,
## nunca CUÁNTOS se colocan.

const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

enum Affinity {
	PERIMETER = 0,       ## Distribuido a lo largo del perímetro / muros
	FOCAL_COMPANION = 1, ## Asociado directamente al prop focal principal (sarcófago, altar)
	FREE = 2             ## Libre / distribuido por el suelo o superficies
}

@export var rule_id: StringName = &""
@export var target_fixture_types: Array[int] = [] ## Array de FixtureStyle.Type
@export var target_fixture_ids: Array[StringName] = []
@export var placement_mode: int = _FixturePlacementModeScript.Mode.WALL
@export var affinity: int = Affinity.PERIMETER
@export var min_count: int = 1
@export var max_count: int = 3

func _init(
	p_mode: int = 0,
	p_min: int = 1,
	p_max: int = 3,
	p_affinity: int = 0,
	p_types: Array[int] = [],
	p_rule_id: StringName = &""
) -> void:
	placement_mode = p_mode
	min_count = p_min
	max_count = p_max
	affinity = p_affinity
	target_fixture_types = p_types
	rule_id = p_rule_id
