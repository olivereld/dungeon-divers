class_name MovementRules
extends RefCounted

## Validador de transiciones espaciales y reglas de movimiento (A -> B).
## Evalúa límites, walkability, elevación, agua, footprint y obstáculos estáticos.

const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _GridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _OccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")

## Callback conceptual opcional para comprobar obstáculos estáticos adicionales: func(cell: Vector2i) -> bool
var static_obstacle_checker: Callable = Callable()

## Valida si una transición desde from_cell hacia to_cell es legal para el perfil y grid dados.
func validate_transition(
	from_cell: Vector2i,
	to_cell: Vector2i,
	grid: MovementGrid,
	profile: MovementProfile,
	occupancy: MovementOccupancy = null,
	entity: Object = null
) -> MovementResult:
	if grid == null:
		return _ResultScript.reject(_ResultScript.REASON_OUT_OF_BOUNDS, from_cell, to_cell)

	# 1. Dirección permitida según perfil
	var dir := to_cell - from_cell
	if profile != null and not profile.is_direction_allowed(dir):
		return _ResultScript.reject(_ResultScript.REASON_DIRECTION_NOT_ALLOWED, from_cell, to_cell)

	# 2. Existencia de la celda de origen
	if not grid.has_cell(from_cell):
		return _ResultScript.reject(_ResultScript.REASON_INVALID_SOURCE_CELL, from_cell, to_cell)

	# 3. Límites del mundo / existencia de la celda destino
	if not grid.has_cell(to_cell):
		return _ResultScript.reject(_ResultScript.REASON_OUT_OF_BOUNDS, from_cell, to_cell)

	# 4. Transitable por terreno base (Walkability)
	if not grid.is_walkable(to_cell):
		return _ResultScript.reject(_ResultScript.REASON_UNWALKABLE, from_cell, to_cell)

	# 5. Restricción de agua
	var in_water: bool = grid.is_water(to_cell)
	var water_mode: int = profile.water_mode if profile != null else _ProfileScript.WaterMode.LAND
	if in_water and water_mode == _ProfileScript.WaterMode.LAND:
		return _ResultScript.reject(_ResultScript.REASON_WATER_BLOCKED, from_cell, to_cell)

	# 6. Desnivel de elevación discreta
	if water_mode != _ProfileScript.WaterMode.FLY:
		var cur_level: int = grid.get_elevation_level(from_cell)
		var target_level: int = grid.get_elevation_level(to_cell)
		var delta_level: int = target_level - cur_level

		var max_up: int = profile.max_step_up if profile != null else 1
		var max_down: int = profile.max_step_down if profile != null else 1

		if delta_level > max_up:
			return _ResultScript.reject(_ResultScript.REASON_ELEVATION_TOO_HIGH, from_cell, to_cell)
		if delta_level < -max_down:
			return _ResultScript.reject(_ResultScript.REASON_ELEVATION_TOO_LOW, from_cell, to_cell)

	# 7. Obstáculos estáticos en destino (interfaz conceptual)
	if static_obstacle_checker.is_valid():
		if static_obstacle_checker.call(to_cell):
			return _ResultScript.reject(_ResultScript.REASON_BLOCKED_BY_OBSTACLE, from_cell, to_cell)

	# 8. Validación de esquinas ortogonales para movimientos diagonales
	if abs(dir.x) == 1 and abs(dir.y) == 1:
		var corner_rule: int = profile.diagonal_corner_rule if profile != null else _ProfileScript.DiagonalCornerRule.BOTH_BLOCKED
		if corner_rule != _ProfileScript.DiagonalCornerRule.NONE:
			var c1 := Vector2i(from_cell.x + dir.x, from_cell.y)
			var c2 := Vector2i(from_cell.x, from_cell.y + dir.y)
			var c1_passable: bool = _is_cell_passable(from_cell, c1, grid, profile)
			var c2_passable: bool = _is_cell_passable(from_cell, c2, grid, profile)

			if corner_rule == _ProfileScript.DiagonalCornerRule.BOTH_BLOCKED:
				if (not c1_passable) and (not c2_passable):
					return _ResultScript.reject(_ResultScript.REASON_DIAGONAL_CORNER_BLOCKED, from_cell, to_cell)
			elif corner_rule == _ProfileScript.DiagonalCornerRule.STRICT:
				if (not c1_passable) or (not c2_passable):
					return _ResultScript.reject(_ResultScript.REASON_DIAGONAL_CORNER_BLOCKED, from_cell, to_cell)

	# 9. Ocupación dinámica de destino (si se provee)
	if occupancy != null and occupancy.is_occupied(to_cell, entity):
		return _ResultScript.reject(_ResultScript.REASON_OCCUPIED, from_cell, to_cell)

	return _ResultScript.accept(from_cell, to_cell)

## Comprueba si una celda ortogonal es transitable y compatible en elevación con from_cell.
func _is_cell_passable(
	from_cell: Vector2i,
	cell: Vector2i,
	grid: MovementGrid,
	profile: MovementProfile
) -> bool:
	if not grid.has_cell(cell):
		return false
	if not grid.is_walkable(cell):
		return false

	var water_mode: int = profile.water_mode if profile != null else _ProfileScript.WaterMode.LAND
	if grid.is_water(cell) and water_mode == _ProfileScript.WaterMode.LAND:
		return false

	if water_mode != _ProfileScript.WaterMode.FLY:
		var cur_lvl: int = grid.get_elevation_level(from_cell)
		var cell_lvl: int = grid.get_elevation_level(cell)
		var delta_lvl: int = cell_lvl - cur_lvl
		var max_up: int = profile.max_step_up if profile != null else 1
		var max_down: int = profile.max_step_down if profile != null else 1
		if delta_lvl > max_up or delta_lvl < -max_down:
			return false

	if static_obstacle_checker.is_valid() and static_obstacle_checker.call(cell):
		return false

	return true
