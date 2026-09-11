class_name WatershedIntegrityChecker
extends RefCounted

## Cierre formal de integridad de Watersheds (Cuencas Hidrográficas).
## Verifica los 3 invariantes topológicos: bijección, aciclicidad y validez de outlets.

static func check(
	cells: Dictionary,
	cell_basin_map: Dictionary,
	basins: Dictionary,
	flow_to: Dictionary,
	width: int,
	height: int
) -> Dictionary:
	var bijection_violations: Array[Vector2i] = []
	var cycle_violations: Array[Vector2i] = []
	var invalid_outlet_violations: Array[int] = []
	var orphan_cells: Array[Vector2i] = []

	var total_cells: int = width * height

	# -------------------------------------------------------------------------
	# Invariante 1: Bijección celda -> cuenca exactamente una
	# -------------------------------------------------------------------------
	var cell_coverage: Dictionary = {}

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue

			if not cell_basin_map.has(pos):
				bijection_violations.append(pos)
				orphan_cells.append(pos)
			else:
				var b_id: int = int(cell_basin_map[pos])
				if b_id == -1:
					# Celda explícitamente descartada (válida)
					cell_coverage[pos] = -1

	# Verificar solapamientos y cobertura desde la unión de basin.cells
	for b_id in basins:
		var basin_data: Dictionary = basins[b_id]
		var b_cells: Array = basin_data.get("cells", [])
		for pos in b_cells:
			if cell_coverage.has(pos):
				# Solapamiento detectado (aparece en más de un basin o basin + descartada)
				bijection_violations.append(pos)
			else:
				cell_coverage[pos] = b_id

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if cells.has(pos) and not cell_coverage.has(pos):
				orphan_cells.append(pos)

	# -------------------------------------------------------------------------
	# Invariante 3: Outlet válido y único por cuenca
	# -------------------------------------------------------------------------
	var seen_outlets: Dictionary = {}

	for b_id in basins:
		var basin_data: Dictionary = basins[b_id]
		var outlet: Vector2i = basin_data.get("outlet", Vector2i(-1, -1))
		var b_cells: Array = basin_data.get("cells", [])
		var b_cells_set: Dictionary = {}
		for p in b_cells:
			b_cells_set[p] = true

		var outlet_valid: bool = true

		# a) flow_to[outlet] == outlet (terminal)
		if flow_to.get(outlet, Vector2i(-999, -999)) != outlet:
			outlet_valid = false

		# b) outlet pertenece a basin.cells
		if not b_cells_set.has(outlet):
			outlet_valid = false

		# c) outlet no duplicado entre basins
		if seen_outlets.has(outlet):
			outlet_valid = false
		else:
			seen_outlets[outlet] = b_id

		if not outlet_valid:
			invalid_outlet_violations.append(int(b_id))

	# -------------------------------------------------------------------------
	# Invariante 2: Ausencia de ciclos dentro del basin y convergencia a outlet
	# -------------------------------------------------------------------------
	for b_id in basins:
		var basin_data: Dictionary = basins[b_id]
		var outlet: Vector2i = basin_data.get("outlet", Vector2i(-1, -1))
		var b_cells: Array = basin_data.get("cells", [])
		var max_steps: int = basin_data.get("area", b_cells.size()) + 5

		for start_pos in b_cells:
			var curr: Vector2i = start_pos
			var visited: Dictionary = {}
			var reached_outlet: bool = false
			var steps: int = 0

			while steps <= max_steps:
				if curr == outlet:
					reached_outlet = true
					break

				if visited.has(curr):
					# Ciclo detectado
					break
				visited[curr] = true

				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr:
					# Terminal distinto al outlet del basin
					break

				curr = nxt
				steps += 1

			if not reached_outlet:
				cycle_violations.append(start_pos)

	return {
		"bijection_violations": bijection_violations,
		"cycle_violations": cycle_violations,
		"invalid_outlet_violations": invalid_outlet_violations,
		"orphan_cells": orphan_cells
	}
