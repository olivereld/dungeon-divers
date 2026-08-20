class_name CorridorLightPlanner
extends RefCounted

## Planificador determinista de iluminación para pasillos y corredores de mazmorra.
## Coloca antorchas en tramos largos con cadencia rítmica y en esquinas de giro clave.

const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _DungeonLightingConfigScript = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func plan_corridor_lights(
	corridor: CorridorPath,
	candidates: Array,
	config: DungeonLightingConfig,
	seed_val: int
) -> Array[LightPlacement]:
	var selected: Array[LightPlacement] = []
	if corridor == null or candidates.is_empty() or config == null or not config.enabled:
		return selected
	if not config.corridor_lighting_enabled:
		return selected

	var length: int = corridor.carved_cells.size()
	if length < config.corridor_min_length:
		return selected

	# Calcular cantidad de luces según longitud
	var target_count: int = maxi(1, int(round(float(length) / float(config.corridor_spacing))))

	# Mapear candidatos por celda
	var cands_by_cell: Dictionary = {}
	for c in candidates:
		if not cands_by_cell.has(c.cell):
			cands_by_cell[c.cell] = []
		cands_by_cell[c.cell].append(c)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Distribuir a lo largo de la trayectoria del pasillo
	var step: float = float(length) / float(target_count + 1)
	var min_spacing_sq: float = float(config.corridor_spacing * config.corridor_spacing) * 0.45

	for i in range(1, target_count + 1):
		var target_idx: int = clampi(int(round(float(i) * step)), 0, length - 1)
		var target_cell: Vector2i = corridor.carved_cells[target_idx]

		# Buscar el candidato más cercano a target_cell
		var best_cand: _LightPlacementScript = null
		var best_dist: float = 9999.0

		for c in candidates:
			var d: float = Vector2(c.cell).distance_to(Vector2(target_cell))
			if d < best_dist:
				# Validar que no esté demasiado cerca de otra luz ya seleccionada
				var too_close: bool = false
				for s in selected:
					if Vector2(c.cell).distance_squared_to(Vector2(s.cell)) < min_spacing_sq:
						too_close = true
						break
				if not too_close:
					best_dist = d
					best_cand = c

		if best_cand != null:
			selected.append(best_cand)

	return selected
