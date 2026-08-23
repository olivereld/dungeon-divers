class_name FixtureBudgetRule
extends Resource

## Regla declarativa de presupuesto mínimo/máximo por modo de colocación de fixtures.

const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

@export var placement_mode: int = _FixturePlacementModeScript.Mode.WALL
@export var min_count: int = 1
@export var max_count: int = 3

func _init(p_mode: int = 0, p_min: int = 1, p_max: int = 3) -> void:
	placement_mode = p_mode
	min_count = p_min
	max_count = p_max
