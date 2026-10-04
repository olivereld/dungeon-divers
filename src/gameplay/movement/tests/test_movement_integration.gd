extends SceneTree

const _GridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _OccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _RequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")
const _ComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _NPCTestScript = preload("res://src/gameplay/movement/npc_movement_test.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Movement Integration Tests")
	print("==================================================")

	_run_synthetic_scenario_integration()
	_run_input_buffering_integration()
	_run_8way_movement_integration()
	_run_world_generator_pipeline_integration()

	print("==================================================")
	print(" ALL MOVEMENT INTEGRATION TESTS PASSED!")
	print("==================================================")
	quit()

func _run_synthetic_scenario_integration() -> void:
	print(" -> Testing synthetic scenario: flat, +1 level, +2 levels, blocked, water, occupied...")

	var root := Node3D.new()
	root.name = "TestRoot"

	var cells_dict := {}

	# (0, 0): plana, level 1, height 1.0
	var c00 = _WorldCellScript.new(Vector2i(0, 0))
	c00.elevation_level = 1
	c00.height = 1.0
	c00.is_walkable = true
	cells_dict[Vector2i(0, 0)] = c00

	# (1, 0): plana vecina, level 1, height 1.0
	var c10 = _WorldCellScript.new(Vector2i(1, 0))
	c10.elevation_level = 1
	c10.height = 1.0
	c10.is_walkable = true
	cells_dict[Vector2i(1, 0)] = c10

	# (1, 1): +1 nivel, level 2, height 2.0
	var c11 = _WorldCellScript.new(Vector2i(1, 1))
	c11.elevation_level = 2
	c11.height = 2.0
	c11.is_walkable = true
	cells_dict[Vector2i(1, 1)] = c11

	# (1, 2): +2 niveles respecto a c11 (level 4, height 4.0)
	var c12 = _WorldCellScript.new(Vector2i(1, 2))
	c12.elevation_level = 4
	c12.height = 4.0
	c12.is_walkable = true
	cells_dict[Vector2i(1, 2)] = c12

	# (2, 0): celda bloqueada / unwalkable
	var c20 = _WorldCellScript.new(Vector2i(2, 0))
	c20.elevation_level = 1
	c20.height = 1.0
	c20.is_walkable = false
	cells_dict[Vector2i(2, 0)] = c20

	# (0, 1): agua
	var hydro_script := GDScript.new()
	hydro_script.source_code = """
extends RefCounted
func is_water(pos: Vector2i) -> bool:
	return pos == Vector2i(0, 1)
"""
	hydro_script.reload()
	var hydro = RefCounted.new()
	hydro.set_script(hydro_script)

	var c01 = _WorldCellScript.new(Vector2i(0, 1))
	c01.elevation_level = 1
	c01.height = 0.5
	c01.is_walkable = true
	cells_dict[Vector2i(0, 1)] = c01

	var grid: MovementGrid = _GridScript.new(1.0, Vector3.ZERO)
	grid.setup_from_cells(cells_dict, hydro)

	var occupancy: MovementOccupancy = _OccupancyScript.new()
	var rules: MovementRules = _RulesScript.new()

	# Instanciar Player en (0, 0)
	var player: PlayerTest = _PlayerTestScript.new()
	root.add_child(player)
	player.setup_movement(grid, occupancy, Vector2i(0, 0))

	# Instanciar NPC en (1, 0)
	var npc = _NPCTestScript.new()
	root.add_child(npc)
	npc.setup_movement(grid, occupancy, Vector2i(1, 0))

	assert(player.get_current_cell() == Vector2i(0, 0), "Player initial cell must be (0, 0)")
	assert(npc.movement_component.current_cell == Vector2i(1, 0), "NPC initial cell must be (1, 0)")
	assert(occupancy.is_occupied(Vector2i(0, 0)), "(0, 0) must be occupied by Player")
	assert(occupancy.is_occupied(Vector2i(1, 0)), "(1, 0) must be occupied by NPC")

	# 1. Player intenta moverse hacia (1, 0), que está ocupada por el NPC
	var req_to_npc := _RequestScript.new(Vector2i(1, 0), &"player")
	var res_occupied: MovementResult = player.movement_component.request_movement(req_to_npc)
	assert(res_occupied.accepted == false, "Player move towards occupied cell must be rejected")
	assert(res_occupied.reason == _ResultScript.REASON_OCCUPIED, "Reason must be REASON_OCCUPIED")

	# 2. Player intenta moverse hacia (0, 1), que es agua (modo LAND)
	var req_to_water := _RequestScript.new(Vector2i(0, 1), &"player")
	var res_water: MovementResult = player.movement_component.request_movement(req_to_water)
	assert(res_water.accepted == false, "Player move towards water cell must be rejected")
	assert(res_water.reason == _ResultScript.REASON_WATER_BLOCKED, "Reason must be REASON_WATER_BLOCKED")

	# 3. NPC se desplaza de (1, 0) a (1, 1) (+1 nivel de elevación, permitido)
	var npc_res: MovementResult = npc.step(Vector2i(0, 1))
	assert(npc_res.accepted == true, "NPC +1 step up to (1, 1) must be accepted")
	assert(npc.movement_component.is_moving == true, "NPC must be in moving state")
	assert(occupancy.is_occupied(Vector2i(1, 1)), "(1, 1) must be reserved in occupancy")

	# Simular avance de tiempo para completar la transición del NPC
	# cps = 3.0, delta = 0.5s -> 2 frames
	npc.movement_component.process_movement(0.2)
	assert(npc.movement_component.is_moving == true, "NPC still moving at t=0.2s")
	npc.movement_component.process_movement(0.2)
	assert(npc.movement_component.is_moving == false, "NPC must finish moving at t=0.4s")
	assert(npc.movement_component.current_cell == Vector2i(1, 1), "NPC current cell is now (1, 1)")
	assert(not occupancy.is_occupied(Vector2i(1, 0)), "(1, 0) must now be free after NPC moved")

	# 4. Ahora Player intenta moverse hacia (1, 0) que quedó libre
	var player_res: MovementResult = player.movement_component.request_movement(req_to_npc)
	assert(player_res.accepted == true, "Player move to freed cell (1, 0) must be accepted")
	assert(player.movement_component.is_moving == true, "Player is moving")

	# Completar transición de Player a (1, 0)
	player.movement_component.process_movement(0.3)
	assert(player.movement_component.is_moving == false, "Player finished moving to (1, 0)")
	assert(player.get_current_cell() == Vector2i(1, 0), "Player current cell is (1, 0)")

	# 5. Desde (1, 0), Player intenta moverse hacia (2, 0) (bloqueada / unwalkable)
	var req_to_blocked := _RequestScript.new(Vector2i(1, 0), &"player")
	var res_blocked: MovementResult = player.movement_component.request_movement(req_to_blocked)
	assert(res_blocked.accepted == false, "Move to blocked cell must be rejected")
	assert(res_blocked.reason == _ResultScript.REASON_UNWALKABLE, "Reason must be REASON_UNWALKABLE")

	# 6. Desde (1, 1), NPC intenta moverse hacia (1, 2) (+2 niveles de elevación: level 2 -> 4)
	var npc_step_up2: MovementResult = npc.step(Vector2i(0, 1))
	assert(npc_step_up2.accepted == false, "Step up +2 levels must be rejected")
	assert(npc_step_up2.reason == _ResultScript.REASON_ELEVATION_TOO_HIGH, "Reason must be REASON_ELEVATION_TOO_HIGH")

	print("    [PASS] synthetic scenario integration")

func _run_input_buffering_integration() -> void:
	print(" -> Testing single-move input buffering during transition...")

	var cells_dict := {}
	for i in range(5):
		var c = _WorldCellScript.new(Vector2i(i, 0))
		c.elevation_level = 0
		c.height = 0.0
		c.is_walkable = true
		cells_dict[Vector2i(i, 0)] = c

	var grid: MovementGrid = _GridScript.new(1.0, Vector3.ZERO)
	grid.setup_from_cells(cells_dict)

	var occupancy: MovementOccupancy = _OccupancyScript.new()
	var comp: MovementComponent = _ComponentScript.new()
	comp.profile = _ProfileScript.new()
	comp.profile.cells_per_second = 2.0 # 0.5s per cell

	comp.setup(grid, occupancy, null, Vector2i(0, 0))

	# 1. Iniciar primer movimiento (0, 0) -> (1, 0)
	var req1 := _RequestScript.new(Vector2i(1, 0), &"player")
	var res1 := comp.request_movement(req1)
	assert(res1.accepted == true, "First move accepted")
	assert(comp.is_moving == true, "Component is moving")

	# Avanzar a la mitad del movimiento (t = 0.25s, progress = 0.5)
	comp.process_movement(0.25)
	assert(comp.is_moving == true, "Still moving at halfway")
	assert(absf(comp.progress - 0.5) < 0.01, "Progress around 0.5")

	# 2. Mientras está en movimiento, enviar siguiente solicitud (1, 0) -> (2, 0)
	var req2 := _RequestScript.new(Vector2i(1, 0), &"player")
	var res2 := comp.request_movement(req2)
	assert(res2.accepted == false, "While moving, immediate request rejected")
	assert(res2.reason == _ResultScript.REASON_ALREADY_MOVING, "Reason is ALREADY_MOVING")
	assert(comp.buffered_request == req2, "Request was stored in buffer")

	# 3. Completar el primer movimiento (t += 0.25s)
	# Al finalizar, MovementComponent debe consumir automáticamente buffered_request e iniciar (1, 0) -> (2, 0)
	comp.process_movement(0.25)
	assert(comp.current_cell == Vector2i(1, 0), "Finished transition to (1, 0)")
	assert(comp.is_moving == true, "Automatically started next buffered transition to (2, 0)")
	assert(comp.target_cell == Vector2i(2, 0), "Target cell is now (2, 0)")
	assert(comp.buffered_request == null, "Buffer was cleared upon consumption")

	# 4. Completar el segundo movimiento
	comp.process_movement(0.5)
	assert(comp.is_moving == false, "Second transition finished")
	assert(comp.current_cell == Vector2i(2, 0), "Final cell is (2, 0)")

	print("    [PASS] input buffering integration")

func _run_8way_movement_integration() -> void:
	print(" -> Testing 8-way native transitions, diagonal corner blocking, and single A -> B move...")

	var root := Node3D.new()
	var cells_dict := {}

	# 4x4 grid de celdas planas transitables
	for y in range(4):
		for x in range(4):
			var c = _WorldCellScript.new(Vector2i(x, y))
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_dict[Vector2i(x, y)] = c

	var grid: MovementGrid = _GridScript.new(1.0, Vector3.ZERO)
	grid.setup_from_cells(cells_dict)

	var occupancy: MovementOccupancy = _OccupancyScript.new()
	var player: PlayerTest = _PlayerTestScript.new()
	root.add_child(player)
	player.setup_movement(grid, occupancy, Vector2i(1, 1))

	# 1. Movimiento diagonal como transición única directa A -> B (no N + E)
	var req_ne := _RequestScript.new(Vector2i(1, -1), &"player") # Noreste
	var res_ne: MovementResult = player.movement_component.request_movement(req_ne)
	assert(res_ne.accepted == true, "Diagonal transition NE must be accepted")
	assert(player.movement_component.is_moving == true, "Player is moving diagonally")
	assert(player.movement_component.facing == Vector2i(1, -1), "Facing must be NE (1, -1)")
	assert(player.movement_component.target_cell == Vector2i(2, 0), "Target cell must be (2, 0)")

	# A mitad de camino, la celda lógica DEBE seguir siendo la de origen (1, 1)
	player.movement_component.process_movement(0.1)
	assert(player.get_current_cell() == Vector2i(1, 1), "Logical cell remains (1, 1) during transition")

	# Al completar la transición, pasa atómicamente a (2, 0)
	player.movement_component.process_movement(0.5)
	assert(player.movement_component.is_moving == false, "Player finished diagonal move")
	assert(player.get_current_cell() == Vector2i(2, 0), "Player current cell is now directly (2, 0)")

	# 2. Diagonal con esquinas bloqueadas (corner blocking)
	# Desde (2, 0), intentar diagonal hacia (3, 1) con esquinas ortogonales (3, 0) y (2, 1) bloqueadas
	cells_dict[Vector2i(3, 0)].is_walkable = false
	cells_dict[Vector2i(2, 1)].is_walkable = false

	var req_se := _RequestScript.new(Vector2i(1, 1), &"player") # Sureste hacia (3, 1)
	var res_corner_blocked: MovementResult = player.movement_component.request_movement(req_se)
	assert(res_corner_blocked.accepted == false, "Diagonal must be rejected when both orthogonal corners are blocked")
	assert(res_corner_blocked.reason == _ResultScript.REASON_DIAGONAL_CORNER_BLOCKED, "Reason must be REASON_DIAGONAL_CORNER_BLOCKED")

	# Liberar una esquina ortogonal (3, 0)
	cells_dict[Vector2i(3, 0)].is_walkable = true
	var res_corner_freed: MovementResult = player.movement_component.request_movement(req_se)
	assert(res_corner_freed.accepted == true, "Diagonal must be accepted when passage is clear through at least one corner")

	# Completar el movimiento diagonal
	player.movement_component.process_movement(0.5)
	assert(player.get_current_cell() == Vector2i(3, 1), "Player reached (3, 1)")

	print("    [PASS] 8-way native transitions & diagonal corner blocking")

func _run_world_generator_pipeline_integration() -> void:
	print(" -> Testing full world pipeline integration with real generated terrain...")

	var pipeline := _WorldPipelineScript.new()
	var profile := _TaigaWorldProfileScript.new()
	var result: WorldResult = pipeline.generate(12345, profile)
	assert(result != null, "World generation must succeed")

	var grid: MovementGrid = _GridScript.new()
	grid.setup_from_world_result(result, profile.cell_size)

	var spawn_cell := grid.world_to_cell(result.spawn_position)
	assert(grid.has_cell(spawn_cell), "Spawn cell must exist in grid")
	assert(grid.is_walkable(spawn_cell), "Spawn cell must be walkable")

	var occupancy: MovementOccupancy = _OccupancyScript.new()
	var player: PlayerTest = _PlayerTestScript.new()
	player.setup_movement(grid, occupancy, spawn_cell)

	assert(player.get_current_cell() == spawn_cell, "Player initial cell matches spawn")

	# Buscar un vecino transitable para verificar transición real sobre el mapa de Taiga
	var test_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var moved := false
	for d in test_dirs:
		var target := spawn_cell + d
		if grid.has_cell(target) and grid.is_walkable(target) and not grid.is_water(target):
			var cur_lvl := grid.get_elevation_level(spawn_cell)
			var tgt_lvl := grid.get_elevation_level(target)
			if absi(tgt_lvl - cur_lvl) <= 1:
				var req := _RequestScript.new(d, &"test")
				var res := player.movement_component.request_movement(req)
				if res.accepted:
					player.movement_component.process_movement(1.0) # Complete move
					assert(player.get_current_cell() == target, "Player reached target cell on real world")
					moved = true
					break

	assert(moved == true, "Player must successfully move to at least one valid neighboring cell on real terrain")

	print("    [PASS] full world pipeline integration")
