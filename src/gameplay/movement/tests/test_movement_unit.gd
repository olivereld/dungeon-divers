extends SceneTree

const _GridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _OccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _RequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Movement Unit Tests")
	print("==================================================")

	_test_cell_world_conversions()
	_test_movement_rules()
	_test_movement_occupancy()
	_test_dynamic_chunk_query()

	print("==================================================")
	print(" ALL MOVEMENT UNIT TESTS PASSED!")
	print("==================================================")
	quit()

func _test_cell_world_conversions() -> void:
	print(" -> Testing cell <-> world coordinate conversions...")
	var grid: MovementGrid = MovementGrid.new(1.0, Vector3.ZERO)

	var cell := Vector2i(5, 8)
	var dummy_cell = _WorldCellScript.new(cell)
	dummy_cell.height = 3.5
	grid.setup_from_cells({cell: dummy_cell}, null, 1.0, Vector3.ZERO)

	var world_pos := grid.cell_to_world(cell)
	assert(absf(world_pos.x - 5.5) < 0.001, "Cell X center must be 5.5")
	assert(absf(world_pos.z - 8.5) < 0.001, "Cell Z center must be 8.5")
	assert(absf(world_pos.y - 3.5) < 0.001, "Height must be 3.5")

	var roundtrip_cell := grid.world_to_cell(world_pos)
	assert(roundtrip_cell == cell, "world_to_cell must recover original cell")

	# Test with cell_size = 2.0 and origin = (10, 0, 10)
	grid.setup_from_cells({cell: dummy_cell}, null, 2.0, Vector3(10.0, 0.0, 10.0))
	var scaled_pos := grid.cell_to_world(cell)
	assert(absf(scaled_pos.x - (10.0 + 5.5 * 2.0)) < 0.001, "Scaled world X mismatch")
	assert(absf(scaled_pos.z - (10.0 + 8.5 * 2.0)) < 0.001, "Scaled world Z mismatch")
	var scaled_roundtrip := grid.world_to_cell(scaled_pos)
	assert(scaled_roundtrip == cell, "Scaled world_to_cell must recover original cell")
	print("    [PASS] cell <-> world conversions")

func _test_movement_rules() -> void:
	print(" -> Testing movement rules validation...")
	var rules: MovementRules = MovementRules.new()
	var profile: MovementProfile = MovementProfile.new()
	profile.max_step_up = 1
	profile.max_step_down = 1

	var cells_dict := {}

	# Celda base
	var c_base = _WorldCellScript.new(Vector2i(0, 0))
	c_base.elevation_level = 2
	c_base.height = 2.0
	c_base.is_walkable = true
	cells_dict[Vector2i(0, 0)] = c_base

	# Celda misma elevación
	var c_flat = _WorldCellScript.new(Vector2i(1, 0))
	c_flat.elevation_level = 2
	c_flat.height = 2.0
	c_flat.is_walkable = true
	cells_dict[Vector2i(1, 0)] = c_flat

	# Celda +1 nivel
	var c_up1 = _WorldCellScript.new(Vector2i(0, 1))
	c_up1.elevation_level = 3
	c_up1.height = 3.0
	c_up1.is_walkable = true
	cells_dict[Vector2i(0, 1)] = c_up1

	# Celda +2 niveles
	var c_up2 = _WorldCellScript.new(Vector2i(0, -1))
	c_up2.elevation_level = 4
	c_up2.height = 4.0
	c_up2.is_walkable = true
	cells_dict[Vector2i(0, -1)] = c_up2

	# Celda -2 niveles
	var c_down2 = _WorldCellScript.new(Vector2i(-1, 0))
	c_down2.elevation_level = 0
	c_down2.height = 0.0
	c_down2.is_walkable = true
	cells_dict[Vector2i(-1, 0)] = c_down2

	# Celda no caminable
	var c_blocked = _WorldCellScript.new(Vector2i(2, 0))
	c_blocked.elevation_level = 2
	c_blocked.is_walkable = false
	cells_dict[Vector2i(2, 0)] = c_blocked

	# Hydrology mock
	var hydro_script := GDScript.new()
	hydro_script.source_code = """
extends RefCounted
func is_water(pos: Vector2i) -> bool:
	return pos == Vector2i(1, 1)
"""
	hydro_script.reload()
	var hydro_mock: RefCounted = RefCounted.new()
	hydro_mock.set_script(hydro_script)

	var c_water = _WorldCellScript.new(Vector2i(1, 1))
	c_water.elevation_level = 2
	c_water.is_walkable = true
	cells_dict[Vector2i(1, 1)] = c_water

	var grid: MovementGrid = MovementGrid.new(1.0, Vector3.ZERO)
	grid.setup_from_cells(cells_dict, hydro_mock)

	# 1. Misma elevación permitida (WALK)
	var res: MovementResult = rules.validate_transition(Vector2i(0, 0), Vector2i(1, 0), grid, profile)
	assert(res.accepted == true, "Same elevation walkable transition must be accepted")
	assert(res.transition_type == _ResultScript.TransitionType.WALK, "Transition type must be WALK")

	# 2. +1 nivel permitido (STEP_UP, max_step_up = 1)
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(0, 1), grid, profile)
	assert(res.accepted == true, "+1 elevation step up must be accepted")
	assert(res.transition_type == _ResultScript.TransitionType.STEP_UP, "Transition type must be STEP_UP")

	# 3. +2 niveles rechazado
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(0, -1), grid, profile)
	assert(res.accepted == false, "+2 elevation must be rejected")
	assert(res.reason == _ResultScript.REASON_ELEVATION_TOO_HIGH, "Reason must be ELEVATION_TOO_HIGH")

	# 4. -2 niveles con can_fall = true -> Aceptado como FALL
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(-1, 0), grid, profile)
	assert(res.accepted == true, "-2 elevation with can_fall=true must be accepted as FALL")
	assert(res.transition_type == _ResultScript.TransitionType.FALL, "Transition type must be FALL")

	# 4B. -2 niveles con can_fall = false -> Rechazado con ELEVATION_TOO_LOW
	profile.can_fall = false
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(-1, 0), grid, profile)
	assert(res.accepted == false, "-2 elevation with can_fall=false must be rejected")
	assert(res.reason == _ResultScript.REASON_FALL_NOT_ALLOWED, "Reason must be FALL_NOT_ALLOWED")
	profile.can_fall = true

	# 4C. Caída que excede max_fall_height -> Rechazada con FALL_TOO_HIGH
	c_down2.elevation_level = -10 # delta = -12 > max_fall_height (6)
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(-1, 0), grid, profile)
	assert(res.accepted == false, "Fall exceeding max_fall_height must be rejected")
	assert(res.reason == _ResultScript.REASON_FALL_TOO_HIGH, "Reason must be FALL_TOO_HIGH")
	c_down2.elevation_level = 0

	# 4D. require_jump_for_elevation = true: bloquea caminar automáticamente con desniveles
	profile.require_jump_for_elevation = true
	# Caminata normal (+1 nivel) -> Rechazada con REASON_JUMP_REQUIRED
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(0, 1), grid, profile, null, null, false)
	assert(res.accepted == false, "Walking up elevation when require_jump=true must be rejected")
	assert(res.reason == _ResultScript.REASON_JUMP_REQUIRED, "Reason must be JUMP_REQUIRED")

	# Salto explícito (+1 nivel, is_jump = true) -> Aceptado como JUMP_UP
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(0, 1), grid, profile, null, null, true)
	assert(res.accepted == true, "Explicit jump up must be accepted")
	assert(res.transition_type == _ResultScript.TransitionType.JUMP_UP, "Transition type must be JUMP_UP")

	# Caminata normal (-2 niveles) -> Rechazada con REASON_JUMP_REQUIRED
	profile.can_drop = true
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(-1, 0), grid, profile, null, null, false)
	assert(res.accepted == false, "Walking off cliff when require_jump=true must be rejected")
	assert(res.reason == _ResultScript.REASON_JUMP_REQUIRED, "Reason must be JUMP_REQUIRED")

	# Salto explícito (-2 niveles, is_jump = true) -> Aceptado como DROP
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(-1, 0), grid, profile, null, null, true)
	assert(res.accepted == true, "Explicit jump down must be accepted as DROP")
	assert(res.transition_type == _ResultScript.TransitionType.DROP, "Transition type must be DROP")

	# Mismo nivel (0 delta) sigue permitido caminando
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(1, 0), grid, profile, null, null, false)
	assert(res.accepted == true, "Walking on same elevation must still be accepted")
	assert(res.transition_type == _ResultScript.TransitionType.WALK, "Transition must be WALK")
	profile.require_jump_for_elevation = false
	profile.can_drop = false

	# 5. Celda bloqueada rechazada
	res = rules.validate_transition(Vector2i(1, 0), Vector2i(2, 0), grid, profile)
	assert(res.accepted == false, "Unwalkable cell must be rejected")
	assert(res.reason == _ResultScript.REASON_UNWALKABLE, "Reason must be UNWALKABLE")

	# 6. Fuera de límites rechazada (usando dirección permitida pero celda inexistente en grid)
	res = rules.validate_transition(Vector2i(0, 1), Vector2i(0, 2), grid, profile) # (0, 2) no existe en el grid
	assert(res.accepted == false, "Out of bounds cell must be rejected")
	assert(res.reason == _ResultScript.REASON_OUT_OF_BOUNDS, "Reason must be OUT_OF_BOUNDS: " + str(res.reason))

	# 7. Agua para LAND rechazada en transición diagonal
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(1, 1), grid, profile)
	assert(res.accepted == false, "Water cell must be rejected for LAND mode")
	assert(res.reason == _ResultScript.REASON_WATER_BLOCKED, "Reason must be WATER_BLOCKED")

	# 8. Agua para SWIM aceptada
	profile.water_mode = _ProfileScript.WaterMode.SWIM
	res = rules.validate_transition(Vector2i(0, 0), Vector2i(1, 1), grid, profile)
	assert(res.accepted == true, "Water cell must be accepted for SWIM mode")
	profile.water_mode = _ProfileScript.WaterMode.LAND

	# 9. Test de esquinas bloqueadas en movimiento diagonal (Corner-cutting rule)
	# Escenario: (0, 0) -> (1, 1) donde (1, 1) es tierra seca
	var c_diag_target = _WorldCellScript.new(Vector2i(2, 2))
	c_diag_target.elevation_level = 2
	c_diag_target.height = 2.0
	c_diag_target.is_walkable = true
	cells_dict[Vector2i(2, 2)] = c_diag_target

	# Origen (1, 1) modificado a tierra seca
	c_water.elevation_level = 2
	# (2, 1) y (1, 2) son los dos vecinos ortogonales de la esquina
	var c_corner_x = _WorldCellScript.new(Vector2i(2, 1))
	c_corner_x.elevation_level = 2
	c_corner_x.is_walkable = false # Bloqueado
	cells_dict[Vector2i(2, 1)] = c_corner_x

	var c_corner_y = _WorldCellScript.new(Vector2i(1, 2))
	c_corner_y.elevation_level = 2
	c_corner_y.is_walkable = false # Bloqueado
	cells_dict[Vector2i(1, 2)] = c_corner_y

	# Caso 9A: Ambas esquinas bloqueadas -> RECHAZADO con BOTH_BLOCKED
	profile.diagonal_corner_rule = _ProfileScript.DiagonalCornerRule.BOTH_BLOCKED
	res = rules.validate_transition(Vector2i(1, 1), Vector2i(2, 2), grid, profile)
	assert(res.accepted == false, "Diagonal must be rejected when both orthogonal corners block passage")
	assert(res.reason == _ResultScript.REASON_DIAGONAL_CORNER_BLOCKED, "Reason must be REASON_DIAGONAL_CORNER_BLOCKED")

	# Caso 9B: Solo una esquina bloqueada -> ACEPTADO con BOTH_BLOCKED
	c_corner_y.is_walkable = true
	res = rules.validate_transition(Vector2i(1, 1), Vector2i(2, 2), grid, profile)
	assert(res.accepted == true, "Diagonal must be accepted when only one corner is blocked under BOTH_BLOCKED")

	# Caso 9C: Con modo STRICT -> RECHAZADO incluso con solo una esquina bloqueada
	profile.diagonal_corner_rule = _ProfileScript.DiagonalCornerRule.STRICT
	res = rules.validate_transition(Vector2i(1, 1), Vector2i(2, 2), grid, profile)
	assert(res.accepted == false, "Diagonal must be rejected under STRICT rule when one corner is blocked")
	assert(res.reason == _ResultScript.REASON_DIAGONAL_CORNER_BLOCKED, "Reason must be REASON_DIAGONAL_CORNER_BLOCKED")

	print("    [PASS] movement rules")

func _test_movement_occupancy() -> void:
	print(" -> Testing dynamic movement occupancy & reservations...")
	var occ: MovementOccupancy = MovementOccupancy.new()
	var entity_a = RefCounted.new()
	var entity_b = RefCounted.new()
	var target_cell := Vector2i(3, 4)

	assert(occ.is_occupied(target_cell) == false, "Target cell initially free")

	# Reserva atómica de A
	var reserved := occ.reserve(target_cell, entity_a)
	assert(reserved == true, "Entity A reservation should succeed")
	assert(occ.is_occupied(target_cell) == true, "Cell is now occupied/reserved")
	assert(occ.is_occupied(target_cell, entity_a) == false, "Cell is not occupied by others relative to A")

	# Intento de reserva de B
	var reserved_b := occ.reserve(target_cell, entity_b)
	assert(reserved_b == false, "Entity B reservation must fail while reserved by A")

	# Completar ocupación de A
	occ.occupy(target_cell, entity_a)
	assert(occ.get_occupant(target_cell) == entity_a, "Occupant must be entity A")

	# Liberar celda
	occ.release(target_cell, entity_a)
	assert(occ.is_occupied(target_cell) == false, "Cell must be free after release")

	# Re-registro y unregister
	occ.occupy(target_cell, entity_a)
	occ.unregister_entity(entity_a)
	assert(occ.is_occupied(target_cell) == false, "Cell must be free after entity unregistration")

	print("    [PASS] movement occupancy & reservations")

func _test_dynamic_chunk_query() -> void:
	print(" -> Testing dynamic chunk/world queries on MovementGrid...")
	var grid: MovementGrid = MovementGrid.new(1.0, Vector3.ZERO)

	# Mock chunk provider object simulating ChunkWorld / WorldChunkManager
	var mock_chunk_system = RefCounted.new()
	var dynamic_cells: Dictionary = {}

	# Define custom method dynamically via lambda or custom provider callable
	var provider_func = func(c: Vector2i):
		return dynamic_cells.get(c, null)

	grid.cell_provider = provider_func
	grid.setup_from_source(mock_chunk_system, 1.0, Vector3.ZERO)

	# 1. Querying an ungenerated cell
	var ungen_cell := Vector2i(100, 200)
	assert(grid.has_cell(ungen_cell) == false, "Ungenerated cell should not exist in grid")
	assert(grid.get_cell(ungen_cell) == null, "get_cell for ungenerated cell must return null")

	# 2. Simulate chunk generation on the fly across chunk boundaries
	var cell_chunk_0 := Vector2i(15, 15)
	var wc_0 = _WorldCellScript.new(cell_chunk_0)
	wc_0.height = 4.2
	wc_0.elevation_level = 4
	dynamic_cells[cell_chunk_0] = wc_0

	var cell_chunk_1 := Vector2i(16, 15) # Next chunk coordinate
	var wc_1 = _WorldCellScript.new(cell_chunk_1)
	wc_1.height = 4.2
	wc_1.elevation_level = 4
	dynamic_cells[cell_chunk_1] = wc_1

	# MovementGrid must see newly generated cells immediately without any rebuild/reset
	assert(grid.has_cell(cell_chunk_0) == true, "Newly generated chunk cell 0 must be accessible")
	assert(grid.has_cell(cell_chunk_1) == true, "Newly generated chunk cell 1 must be accessible")
	assert(absf(grid.get_height(cell_chunk_0) - 4.2) < 0.001, "Height must match dynamic source")
	assert(grid.get_cell(cell_chunk_1) == wc_1, "get_cell must return exact WorldCell instance")

	print("    [PASS] dynamic chunk queries on MovementGrid")

