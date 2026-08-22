class_name FixturePaletteEntry
extends Resource

## Entrada configurable de una paleta de fixtures con peso probabilístico y restricciones.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")

@export var style: _FixtureStyleScript = null
@export_range(0.0, 100.0) var weight: float = 1.0
@export var min_count: int = 0
@export var max_count: int = 999

func _init(
	p_style: _FixtureStyleScript = null,
	p_weight: float = 1.0,
	p_min: int = 0,
	p_max: int = 999
) -> void:
	style = p_style
	weight = maxf(0.0, p_weight)
	min_count = p_min
	max_count = p_max

func to_debug_string() -> String:
	return "PaletteEntry(Style: %s, Weight: %.2f, Min: %d, Max: %d)" % [
		style.id if style != null else "null", weight, min_count, max_count
	]
