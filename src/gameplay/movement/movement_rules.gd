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
	grid: Object,
	profile: MovementProfile,
	occupancy: MovementOccupancy = null,
	entity: Object = null,
	is_jump: bool = false
) -> MovementResult:
	if grid == null:
		return _ResultScript.reject(_ResultScript.REASON_OUT_OF_BOUNDS, from_cell, to_cell)

	# 1. Dirección permitida según perfil
	var dir := to_cell - from_cell
	if profile != null and not profile.is_direction_allowed(dir):
		return _ResultScript.reject(_ResultScript.REASON_DIRECTION_NOT_ALLOWED, from_cell, to_cell)

	# 2. Disponibilidad de chunks / existencia de celdas
	var has_avail: bool = grid.has_method("get_cell_availability") and grid.get_cell_availability(from_cell) != -1
	if has_avail:
		if grid.get_cell_availability(from_cell) != 0: # 0 == READY
			return _ResultScript.reject(_ResultScript.REASON_CHUNK_UNAVAILABLE, from_cell, to_cell)
		if grid.get_cell_availability(to_cell) != 0:
			return _ResultScript.reject(_ResultScript.REASON_CHUNK_UNAVAILABLE, from_cell, to_cell)
	else:
		if not grid.has_cell(from_cell):
			return _ResultScript.reject(_ResultScript.REASON_INVALID_SOURCE_CELL, from_cell, to_cell)
		if not grid.has_cell(to_cell):
			return _ResultScript.reject(_ResultScript.REASON_OUT_OF_BOUNDS, from_cell, to_cell)

	# 3. Transitable por terreno base (Walkability)
	if not grid.is_walkable(to_cell):
		return _ResultScript.reject(_ResultScript.REASON_UNWALKABLE, from_cell, to_cell)

	# 4. Restricción de agua
	var in_water: bool = grid.is_water(to_cell) if grid.has_method("is_water") else false
	var water_mode: int = profile.water_mode if profile != null else _ProfileScript.WaterMode.LAND
	if in_water and water_mode == _ProfileScript.WaterMode.LAND:
		return _ResultScript.reject(_ResultScript.REASON_WATER_BLOCKED, from_cell, to_cell)

	# 5. Desnivel de elevación discreta y clasificación de transición (WALK / STEP_UP / STEP_DOWN / FALL / DROP / JUMP_UP)
	var transition_type: int = _ResultScript.TransitionType.WALK
	if water_mode != _ProfileScript.WaterMode.FLY and (grid.has_method("analyze_transition") or grid.has_method("get_elevation_level")):
		var delta_level: int = 0
		var delta_h: float = 0.0

		if grid.has_method("analyze_transition"):
			var trans: Dictionary = grid.analyze_transition(from_cell, to_cell)
			delta_level = trans.get("delta_level", 0)
			delta_h = trans.get("delta_height", 0.0)
		else:
			var cur_lvl: int = grid.get_elevation_level(from_cell)
			var tgt_lvl: int = grid.get_elevation_level(to_cell)
			delta_level = tgt_lvl - cur_lvl
			if grid.has_method("get_height"):
				delta_h = grid.get_height(to_cell) - grid.get_height(from_cell)
			else:
				delta_h = float(delta_level) * 2.0

		var walk_up: int = profile.max_walk_step_up if profile != null else 0
		var walk_up_h: float = profile.get_effective_walk_step_up_height() if profile != null and profile.has_method("get_effective_walk_step_up_height") else (float(walk_up) * 2.0)
		var jump_up: int = profile.max_jump_up if profile != null else 3
		var jump_up_h: float = profile.get_effective_jump_up_height() if profile != null and profile.has_method("get_effective_jump_up_height") else (float(jump_up) * 2.0)
		var walk_down: int = profile.max_walk_step_down if profile != null else 0
		var walk_down_h: float = profile.get_effective_walk_step_down_height() if profile != null and profile.has_method("get_effective_walk_step_down_height") else (float(walk_down) * 2.0)
		var max_drop: int = profile.max_drop_distance if profile != null else 4
		var max_drop_h: float = profile.get_effective_drop_height() if profile != null and profile.has_method("get_effective_drop_height") else (float(max_drop) * 2.0)
		var require_jump: bool = profile.require_jump_for_elevation if profile != null else false

		var is_rise: bool = (delta_h > 0.05) or (delta_level > 0)
		var is_drop: bool = (delta_h < -0.05) or (delta_level < 0)

		if require_jump and (is_rise or is_drop) and not is_jump:
			return _ResultScript.reject(_ResultScript.REASON_JUMP_REQUIRED, from_cell, to_cell)

		if not is_rise and not is_drop:
			transition_type = _ResultScript.TransitionType.WALK
		elif is_rise:
			var can_walk_step: bool = (delta_level <= walk_up) and (delta_h <= walk_up_h + 0.01)
			if can_walk_step and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_UP
			elif delta_level <= jump_up and delta_h <= jump_up_h + 0.01:
				if not is_jump:
					return _ResultScript.reject(
						_ResultScript.REASON_JUMP_REQUIRED,
						from_cell,
						to_cell
					)
				transition_type = _ResultScript.TransitionType.JUMP_UP
			else:
				return _ResultScript.reject(
					_ResultScript.REASON_ELEVATION_TOO_HIGH,
					from_cell,
					to_cell
				)
		else: # is_drop
			var abs_delta: int = absi(delta_level)
			var abs_delta_h: float = absf(delta_h)

			var can_walk_step_down: bool = (abs_delta <= walk_down) and (abs_delta_h <= walk_down_h + 0.01)
			if can_walk_step_down and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_DOWN
			elif abs_delta <= max_drop and abs_delta_h <= max_drop_h + 0.01 and profile != null and profile.can_drop:
				if not is_jump:
					return _ResultScript.reject(
						_ResultScript.REASON_JUMP_REQUIRED,
						from_cell,
						to_cell
					)
				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_drop)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)
				transition_type = _ResultScript.TransitionType.DROP
			else:
				var can_fall: bool = profile.can_fall if profile != null else true
				if not can_fall:
					if profile != null and profile.can_drop and (abs_delta > max_drop or abs_delta_h > max_drop_h):
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					elif profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_NOT_ALLOWED, from_cell, to_cell)
					else:
						return _ResultScript.reject(_ResultScript.REASON_FALL_NOT_ALLOWED, from_cell, to_cell)

				var max_fall: int = profile.max_fall_height if profile != null else 6
				var max_fall_h: float = float(max_fall) * 2.0
				if abs_delta > max_fall or abs_delta_h > max_fall_h:
					if profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					return _ResultScript.reject(_ResultScript.REASON_FALL_TOO_HIGH, from_cell, to_cell)

				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_fall)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)

				transition_type = _ResultScript.TransitionType.FALL

	# 6. Obstáculos estáticos en destino (interfaz conceptual)
	if static_obstacle_checker.is_valid():
		if static_obstacle_checker.call(to_cell):
			return _ResultScript.reject(_ResultScript.REASON_BLOCKED_BY_OBSTACLE, from_cell, to_cell)

	# 7. Validación de esquinas ortogonales para movimientos diagonales
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

	# 8. Ocupación dinámica de destino (si se provee)
	if occupancy != null and occupancy.is_occupied(to_cell, entity):
		return _ResultScript.reject(_ResultScript.REASON_OCCUPIED, from_cell, to_cell)

	return _ResultScript.accept(from_cell, to_cell, transition_type)

## Comprueba si una celda ortogonal es transitable y compatible en elevación con from_cell.
func _is_cell_passable(
	from_cell: Vector2i,
	cell: Vector2i,
	grid: Object,
	profile: MovementProfile
) -> bool:
	if grid.has_method("get_cell_availability") and grid.get_cell_availability(cell) != -1:
		if grid.get_cell_availability(cell) != 0:
			return false
	else:
		if not grid.has_cell(cell):
			return false

	if not grid.is_walkable(cell):
		return false

	var water_mode: int = profile.water_mode if profile != null else _ProfileScript.WaterMode.LAND
	if grid.has_method("is_water") and grid.is_water(cell) and water_mode == _ProfileScript.WaterMode.LAND:
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
