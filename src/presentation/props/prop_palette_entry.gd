class_name PropPaletteEntry
extends Resource

## Entrada ponderada dentro de una PropPalette.
## Asocia un PropStyle a un peso relativo (weight) y límites opcionales de instanciación.

const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")

@export var style: _PropStyleScript = null
@export var weight: float = 1.0
@export var min_count: int = 0
@export var max_count: int = -1 ## -1 significa sin límite máximo

func _init(
	p_style: _PropStyleScript = null,
	p_weight: float = 1.0,
	p_min: int = 0,
	p_max: int = -1
) -> void:
	style = p_style
	weight = p_weight
	min_count = p_min
	max_count = p_max
