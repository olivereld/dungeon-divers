class_name NavigationStage
extends WorldStage

enum SlopeCategory {
	FLAT,      # 0 - 10 deg
	GENTLE,    # 10 - 25 deg
	STEEP,     # 25 - 40 deg
	CLIFF,     # > 40 deg
}

## Regla de navegación entre celdas para terreno escalonado:
## - different level (level_a != level_b) -> no transición caminable (no es una pendiente caminable;
##   base limpia para conectores explícitos futuros: Ramp, Stairs, Bridge).
## - same level (level_a == level_b) -> transitable según reglas existentes (ambas celdas transitables).
static func can_transition(cell_a: WorldCell, cell_b: WorldCell) -> bool:
	if cell_a == null or cell_b == null:
		return false
	if cell_a.elevation_level != cell_b.elevation_level:
		return false
	return cell_a.is_walkable and cell_b.is_walkable

static func can_transition_pos(result: WorldResult, pos_a: Vector2i, pos_b: Vector2i) -> bool:
	if result == null:
		return false
	return can_transition(result.get_cell(pos_a), result.get_cell(pos_b))


func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var core_bounds: Rect2i = context.get_core_bounds() if context.has_method("get_core_bounds") else Rect2i(0, 0, profile.width, profile.height)
	var is_chunk: bool = context.has_method("is_chunk_context") and context.is_chunk_context()

	var walkable_count: int = 0
	var total_cells: int = core_bounds.size.x * core_bounds.size.y

	var best_spawn_pos := Vector2i(-1, -1)
	var min_spawn_slope := INF
	var center := Vector2(float(profile.width) * 0.5, float(profile.height) * 0.5)

	for pos in context.result.cells.keys():
		var cell := context.result.get_cell(pos)
		if cell == null:
			continue

		var in_core: bool = core_bounds.has_point(pos)

		if cell.slope < 10.0:
			cell.slope_category = SlopeCategory.FLAT
		elif cell.slope < 25.0:
			cell.slope_category = SlopeCategory.GENTLE
		elif cell.slope < 40.0:
			cell.slope_category = SlopeCategory.STEEP
		else:
			cell.slope_category = SlopeCategory.CLIFF

		var is_walkable := (cell.slope <= profile.max_walkable_slope)
		var hydro = context.result.hydrology
		var in_water := false
		if hydro != null and hydro.has_method("is_water") and hydro.is_water(pos):
			in_water = true
			if hydro.has_method("get_water_depth") and hydro.get_water_depth(pos) > 0.4:
				is_walkable = false

		cell.is_walkable = is_walkable
		if in_core and cell.is_walkable:
			walkable_count += 1

			# Prefer spawn near center with lowest slope on dry land (solo para contexto mundial)
			if not is_chunk and not in_water:
				var dist_to_center := Vector2(float(pos.x), float(pos.y)).distance_to(center)
				var score := cell.slope + (dist_to_center * 0.2)
				if score < min_spawn_slope:
					min_spawn_slope = score
					best_spawn_pos = pos

	if not is_chunk:
		if best_spawn_pos != Vector2i(-1, -1):
			var spawn_cell := context.result.get_cell(best_spawn_pos)
			context.result.spawn_position = Vector3(float(best_spawn_pos.x), spawn_cell.height, float(best_spawn_pos.y))

		context.result.metadata["walkable_ratio"] = float(walkable_count) / float(total_cells)
		context.result.metadata["walkable_cells"] = walkable_count
		context.result.metadata["total_cells"] = total_cells
