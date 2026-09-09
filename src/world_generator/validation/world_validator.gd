class_name WorldValidator
extends RefCounted

static func validate(result: WorldResult) -> Dictionary:
	var errors: Array[String] = []

	if result == null:
		return {"valid": false, "errors": ["WorldResult is null"]}

	if result.dimensions.x <= 0 or result.dimensions.y <= 0:
		errors.append("Invalid dimensions: %s" % str(result.dimensions))

	var expected_cells := result.dimensions.x * result.dimensions.y
	if result.cells.size() != expected_cells:
		errors.append("Cell count mismatch: expected %d, got %d" % [expected_cells, result.cells.size()])

	var nan_count := 0
	var invalid_range_count := 0
	var total_walkable := 0

	for pos in result.cells.keys():
		var cell: WorldCell = result.cells[pos]
		if cell.position != pos:
			errors.append("Cell position mismatch at %s (has %s)" % [str(pos), str(cell.position)])
			break

		if is_nan(cell.height) or is_inf(cell.height):
			nan_count += 1
		if cell.slope < 0.0 or cell.slope > 90.0:
			errors.append("Invalid slope %f at %s" % [cell.slope, str(pos)])
			break

		if cell.normalized_height < 0.0 or cell.normalized_height > 1.0001:
			invalid_range_count += 1
		if cell.forest_density < 0.0 or cell.forest_density > 1.0001:
			invalid_range_count += 1
		if cell.clearing_density < 0.0 or cell.clearing_density > 1.0001:
			invalid_range_count += 1
		if cell.moisture < 0.0 or cell.moisture > 1.0001:
			invalid_range_count += 1

		if cell.is_walkable:
			total_walkable += 1

	if nan_count > 0:
		errors.append("Found %d cells with NaN/Inf height" % nan_count)
	if invalid_range_count > 0:
		errors.append("Found %d field values violating [0.0, 1.0] range invariants" % invalid_range_count)

	var walkable_ratio: float = result.metadata.get("walkable_ratio", 0.0)
	if walkable_ratio < 0.60:
		errors.append("Walkable ratio too low: %f (expected >= 0.60)" % walkable_ratio)

	# Spawn position safety & grounding
	var spawn_grid := Vector2i(int(round(result.spawn_position.x)), int(round(result.spawn_position.z)))
	var spawn_cell := result.get_cell(spawn_grid)
	if spawn_cell == null:
		errors.append("Spawn position out of world bounds: %s" % str(result.spawn_position))
	else:
		if not spawn_cell.is_walkable:
			errors.append("Spawn cell at %s is marked not walkable" % str(spawn_grid))
		if absf(spawn_cell.height - result.spawn_position.y) > 0.01:
			errors.append("Spawn position Y (%f) does not match terrain height (%f)" % [result.spawn_position.y, spawn_cell.height])

	# Connected walkable component check (BFS from spawn)
	var reachable_count := 0
	if spawn_cell != null and spawn_cell.is_walkable:
		var visited: Dictionary = {}
		var queue: Array[Vector2i] = [spawn_grid]
		visited[spawn_grid] = true

		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			reachable_count += 1
			var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for offset in offsets:
				var neighbor_pos: Vector2i = cur + offset
				if not visited.has(neighbor_pos) and result.cells.has(neighbor_pos):
					var neighbor_cell: WorldCell = result.cells[neighbor_pos]
					if neighbor_cell.is_walkable:
						visited[neighbor_pos] = true
						queue.append(neighbor_pos)

	var reachable_ratio := float(reachable_count) / float(maxi(total_walkable, 1))
	if reachable_ratio < 0.70:
		errors.append("Spawn point disconnected from main terrain: reachable ratio %f (expected >= 0.70)" % reachable_ratio)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"walkable_ratio": walkable_ratio,
		"reachable_walkable_ratio": reachable_ratio,
		"vegetation_count": result.vegetation.size(),
	}
