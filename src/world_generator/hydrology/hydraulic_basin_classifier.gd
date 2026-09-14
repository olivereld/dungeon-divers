class_name HydraulicBasinClassifier
extends RefCounted

## Clasificador geomorfológico local para depresiones y zonas de convergencia fluvial.
## No depende de los bordes del mapa global, permitiendo portabilidad directa a arquitecturas por Chunks.

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
]

func is_local_depression(
	pos: Vector2i,
	cells: Dictionary,
	filled_height: Dictionary,
	threshold: float = 0.05
) -> bool:
	if not cells.has(pos):
		return false
	var cell = cells[pos]
	var raw_h: float = 0.0
	if "raw_height" in cell:
		raw_h = float(cell.raw_height)
	elif cell is Dictionary and cell.has("raw_height"):
		raw_h = float(cell["raw_height"])
	var fill_h: float = float(filled_height.get(pos, raw_h))
	return fill_h > raw_h + threshold

func detect_convergence_zone(
	active_river_cells: Dictionary,
	pos: Vector2i,
	slope: float,
	radius: int = 3,
	slope_threshold: float = 2.0
) -> bool:
	if slope > slope_threshold:
		return false

	var nearby_rivers: Dictionary = {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_p := pos + Vector2i(dx, dy)
			if active_river_cells.has(check_p):
				var r_id: int = int(active_river_cells[check_p])
				nearby_rivers[r_id] = true

	return nearby_rivers.size() >= 2
