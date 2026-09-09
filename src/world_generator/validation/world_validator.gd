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
	for cell in result.cells.values():
		if is_nan(cell.height) or is_inf(cell.height):
			nan_count += 1
		if cell.slope < 0.0 or cell.slope > 90.0:
			errors.append("Invalid slope %f at %s" % [cell.slope, str(cell.position)])
			break

	if nan_count > 0:
		errors.append("Found %d cells with NaN/Inf height" % nan_count)

	var walkable_ratio: float = result.metadata.get("walkable_ratio", 0.0)
	if walkable_ratio < 0.60:
		errors.append("Walkable ratio too low: %f (expected >= 0.60)" % walkable_ratio)

	if result.spawn_position == Vector3.ZERO and not result.cells.has(Vector2i.ZERO):
		errors.append("Invalid spawn position")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"walkable_ratio": walkable_ratio,
		"vegetation_count": result.vegetation.size(),
	}
