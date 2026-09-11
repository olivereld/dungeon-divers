class_name River
extends RefCounted

## Contrato de datos explícito para un tramo de río individual.
## Representa la verdad topológica e hidrológica calculada en HydrologyStage.

var id: int = -1
var index: int = -1  # Alias para compatibilidad hacia atrás
var source: Vector2i = Vector2i(-1, -1)
var path: Array = []
var cells: Array:
	get:
		return path
	set(val):
		path = val
var length: float = 0.0
var upstream_rivers: Array = []
var downstream_river: int = -1
var order: int = 1  # Strahler stream order
var accumulation_start: float = 1.0
var accumulation_end: float = 1.0
var outlet: Vector2i = Vector2i(-1, -1)
var is_outflow: bool = false

# Representación geométrica calculada (Bloque 9)
var points: Array = []
var widths: Array = []
var depths: Array = []
var meander_offsets: Array = []

func _init(p_id: int = -1, p_source: Vector2i = Vector2i(-1, -1), p_path: Array = []) -> void:
	id = p_id
	index = p_id
	source = p_source
	path = p_path
	length = float(p_path.size())
	if not p_path.is_empty():
		outlet = p_path[-1]

func to_dict() -> Dictionary:
	return {
		"id": id,
		"index": id,
		"source": source,
		"path": path,
		"cells": path,  # Alias para compatibilidad con código existente
		"length": length,
		"upstream_rivers": upstream_rivers,
		"downstream_river": downstream_river,
		"order": order,
		"accumulation_start": accumulation_start,
		"accumulation_end": accumulation_end,
		"outlet": outlet,
		"is_outflow": is_outflow,
		"points": points,
		"widths": widths,
		"depths": depths,
		"meander_offsets": meander_offsets
	}
