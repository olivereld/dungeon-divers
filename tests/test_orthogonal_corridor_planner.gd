extends SceneTree

## Test unitario del planificador ortogonal analítico (OrthogonalCorridorPlanner).
## Valida Nivel 0 (Líneas rectas, 0 giros) y Nivel 1 (Formas en L limpias, 1 giro).

const _PlannerScript = preload("res://src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd")

func _init() -> void:
	print("--- Running test_orthogonal_corridor_planner (Task 2) ---")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(2, 5, 6, 6), &"roomA")
	var r2 := RoomData.new(1, Rect2i(25, 5, 6, 6), &"roomB")
	var r3 := RoomData.new(2, Rect2i(25, 25, 6, 6), &"roomC")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r3.rect, CellGrid.CellType.FLOOR)

	var cfg := DungeonConfig.new()

	# -------------------------------------------------------------
	# Test 1: Nivel 0 - Recta horizontal colineal (start.y == goal.y)
	# -------------------------------------------------------------
	var start_h := Vector2i(8, 7)  # Celda exterior de roomA este
	var goal_h := Vector2i(24, 7)  # Celda exterior de roomB oeste
	var res_straight_h = _PlannerScript.plan_route(grid, [r1, r2, r3], 0, 1, start_h, goal_h, cfg)

	assert(res_straight_h["success"] == true, "Straight horizontal route must succeed")
	assert(res_straight_h["strategy"] == "Straight", "Strategy must be Straight")
	assert(res_straight_h["turns"] == 0, "Straight route must have 0 turns")
	assert(res_straight_h["centerline"].size() == 17, "Length from x=8 to x=24 should be 17 cells")
	assert(res_straight_h["centerline"][0] == start_h, "Start cell must match start_h")
	assert(res_straight_h["centerline"][res_straight_h["centerline"].size() - 1] == goal_h, "Goal cell must match goal_h")
	print("  [OK] Test 1: Straight horizontal route (0 turns) verified")

	# -------------------------------------------------------------
	# Test 2: Nivel 0 - Recta vertical colineal (start.x == goal.x)
	# -------------------------------------------------------------
	var start_v := Vector2i(27, 11) # Celda exterior de roomB sur
	var goal_v := Vector2i(27, 24)  # Celda exterior de roomC norte
	var res_straight_v = _PlannerScript.plan_route(grid, [r1, r2, r3], 1, 2, start_v, goal_v, cfg)

	assert(res_straight_v["success"] == true, "Straight vertical route must succeed")
	assert(res_straight_v["strategy"] == "Straight", "Strategy must be Straight")
	assert(res_straight_v["turns"] == 0, "Straight vertical route must have 0 turns")
	assert(res_straight_v["centerline"][0] == start_v, "Start cell must match start_v")
	assert(res_straight_v["centerline"][res_straight_v["centerline"].size() - 1] == goal_v, "Goal cell must match goal_v")
	print("  [OK] Test 2: Straight vertical route (0 turns) verified")

	# -------------------------------------------------------------
	# Test 3: Nivel 1 - Ruta en L limpia (1 giro) entre roomA y roomC
	# -------------------------------------------------------------
	var start_l := Vector2i(8, 7)   # Salida de roomA
	var goal_l := Vector2i(27, 24)  # Salida de roomC
	var res_l = _PlannerScript.plan_route(grid, [r1, r2, r3], 0, 2, start_l, goal_l, cfg)

	assert(res_l["success"] == true, "L route must succeed")
	assert(res_l["strategy"] in ["L_HV", "L_VH"], "Strategy must be L_HV or L_VH")
	assert(res_l["turns"] == 1, "L route must have exactly 1 turn")
	assert(res_l["centerline"][0] == start_l, "Start cell must match start_l")
	assert(res_l["centerline"][res_l["centerline"].size() - 1] == goal_l, "Goal cell must match goal_l")
	print("  [OK] Test 3: Clean L route (1 turn) verified")

	# -------------------------------------------------------------
	# Test 4: Validación de límites y obstáculos (bloqueo total sin paso)
	# -------------------------------------------------------------
	var grid_blocked := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	grid_blocked.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid_blocked.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	# Poner muro de columnas que corte toda la rejilla de arriba a abajo en x=15
	grid_blocked.fill_rect(Rect2i(15, 0, 2, 40), CellGrid.CellType.COLUMN)

	var res_blocked = _PlannerScript.plan_route(grid_blocked, [r1, r2], 0, 1, start_h, goal_h, cfg)
	assert(res_blocked["success"] == false, "Fully impassable obstacle must return success=false")
	print("  [OK] Test 4: Fully impassable obstacle validation verified")

	# -------------------------------------------------------------
	# Test 5: No atravesar salas ajenas prohibidas
	# -------------------------------------------------------------
	var grid_room_block := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r_middle := RoomData.new(99, Rect2i(12, 4, 8, 8), &"forbiddenRoom")
	grid_room_block.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid_room_block.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	grid_room_block.fill_rect(r_middle.rect, CellGrid.CellType.FLOOR)

	var res_room_blocked = _PlannerScript.plan_route(grid_room_block, [r1, r2, r_middle], 0, 1, start_h, goal_h, cfg)
	if res_room_blocked["success"]:
		for c in res_room_blocked["centerline"]:
			assert(not r_middle.rect.has_point(c), "No cell in corridor centerline may intersect forbidden room interior")
	else:
		assert(not res_room_blocked["success"], "If no detour exists, must fail cleanly")
	print("  [OK] Test 5: Forbidden room interior avoidance verified")

	# -------------------------------------------------------------
	# Test 6: Nivel 2 - Ruta en Z (2 giros: H-V-H) cuando L_HV y L_VH están bloqueadas
	# -------------------------------------------------------------
	var grid_z := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r_za := RoomData.new(0, Rect2i(2, 5, 6, 6), &"roomZA")
	var r_zb := RoomData.new(1, Rect2i(25, 20, 6, 6), &"roomZB")
	grid_z.fill_rect(r_za.rect, CellGrid.CellType.FLOOR)
	grid_z.fill_rect(r_zb.rect, CellGrid.CellType.FLOOR)

	# Bloquear ambas esquinas de L: corner_hv=(27, 7) y corner_vh=(8, 20)
	grid_z.set_cell(Vector2i(27, 7), CellGrid.CellType.COLUMN)
	grid_z.set_cell(Vector2i(8, 20), CellGrid.CellType.COLUMN)

	var start_z := Vector2i(8, 7)
	var goal_z := Vector2i(27, 20)
	var res_z = _PlannerScript.plan_route(grid_z, [r_za, r_zb], 0, 1, start_z, goal_z, cfg)

	assert(res_z["success"] == true, "Multi-turn Z-route must succeed when direct L is blocked")
	assert(res_z["turns"] == 2, "Z-route must have exactly 2 turns, got %d" % res_z.get("turns", -1))
	assert(res_z["strategy"] in ["Z_HVH", "Z_VHV", "U_HVH", "U_VHV"], "Strategy must be multi-turn Z or U")
	assert(res_z["centerline"][0] == start_z, "Start must match start_z")
	assert(res_z["centerline"][res_z["centerline"].size() - 1] == goal_z, "Goal must match goal_z")
	print("  [OK] Test 6: Level 2 Z-route (2 turns) verified")

	# -------------------------------------------------------------
	# Test 7: Nivel 2 - Rodeo en U (2 giros) para esquivar obstáculo en línea recta
	# -------------------------------------------------------------
	var grid_u := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r_ua := RoomData.new(0, Rect2i(2, 10, 6, 6), &"roomUA")
	var r_ub := RoomData.new(1, Rect2i(25, 10, 6, 6), &"roomUB")
	grid_u.fill_rect(r_ua.rect, CellGrid.CellType.FLOOR)
	grid_u.fill_rect(r_ub.rect, CellGrid.CellType.FLOOR)

	# Obstáculo bloqueando directamente la línea recta horizontal y=12
	grid_u.fill_rect(Rect2i(10, 10, 10, 5), CellGrid.CellType.COLUMN)

	var start_u := Vector2i(8, 12)
	var goal_u := Vector2i(24, 12)
	var res_u = _PlannerScript.plan_route(grid_u, [r_ua, r_ub], 0, 1, start_u, goal_u, cfg)

	assert(res_u["success"] == true, "U-route must succeed around collinear obstacle")
	assert(res_u["turns"] >= 2 and res_u["turns"] <= cfg.corridor_max_preferred_turns, "Must respect max turns")
	for c in res_u["centerline"]:
		assert(grid_u.get_cell(c) != CellGrid.CellType.COLUMN, "Path must not hit obstacle")
	print("  [OK] Test 7: Level 2 U-route detour around collinear obstacle verified")

	# -------------------------------------------------------------
	# Test 8: Límite estricto de giros (corridor_max_preferred_turns = 1)
	# -------------------------------------------------------------
	var cfg_strict := DungeonConfig.new()
	cfg_strict.corridor_max_preferred_turns = 1
	var res_strict = _PlannerScript.plan_route(grid_z, [r_za, r_zb], 0, 1, start_z, goal_z, cfg_strict)
	assert(res_strict["success"] == false, "When max_turns=1, 2-turn routes must be rejected")
	print("  [OK] Test 8: corridor_max_preferred_turns limit enforced")

	print("[PASS] test_orthogonal_corridor_planner completed successfully!")
	quit(0)

