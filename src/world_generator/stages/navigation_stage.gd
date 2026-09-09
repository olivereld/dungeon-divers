class_name NavigationStage
extends WorldStage

enum SlopeCategory {
	FLAT,      # 0 - 10 deg
	GENTLE,    # 10 - 25 deg
	STEEP,     # 25 - 40 deg
	CLIFF,     # > 40 deg
}

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var walkable_count: int = 0
	var total_cells: int = profile.width * profile.height

	var best_spawn_pos := Vector2i(-1, -1)
	var min_spawn_slope := INF
	var center := Vector2(float(profile.width) * 0.5, float(profile.height) * 0.5)

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))

			if cell.slope < 10.0:
				cell.slope_category = SlopeCategory.FLAT
			elif cell.slope < 25.0:
				cell.slope_category = SlopeCategory.GENTLE
			elif cell.slope < 40.0:
				cell.slope_category = SlopeCategory.STEEP
			else:
				cell.slope_category = SlopeCategory.CLIFF

			cell.is_walkable = (cell.slope <= profile.max_walkable_slope)
			if cell.is_walkable:
				walkable_count += 1

				# Prefer spawn near center with lowest slope
				var dist_to_center := Vector2(float(x), float(y)).distance_to(center)
				var score := cell.slope + (dist_to_center * 0.2)
				if score < min_spawn_slope:
					min_spawn_slope = score
					best_spawn_pos = Vector2i(x, y)

	if best_spawn_pos != Vector2i(-1, -1):
		var spawn_cell := context.result.get_cell(best_spawn_pos)
		context.result.spawn_position = Vector3(float(best_spawn_pos.x) * profile.cell_size, spawn_cell.height, float(best_spawn_pos.y) * profile.cell_size)

	context.result.metadata["walkable_ratio"] = float(walkable_count) / float(total_cells)
	context.result.metadata["walkable_cells"] = walkable_count
	context.result.metadata["total_cells"] = total_cells
