class_name CorridorConnectivityRepair
extends RefCounted

## Reparador inteligente y atómico de corredores faltantes (Fase 6.1.1).
## Se ejecuta estrictamente después de AStarCarver y antes de DoorResolver.
## Reintenta tallar conexiones obligatorias fallidas mediante relajación controlada
## (p. ej. ancho reducido a 1 celda en zonas estrechas) con rollback garantizado por CellGridJournal.

const _CellGridJournalScript = preload("res://src/dungeon_generator/core/repair/cell_grid_journal.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _CorridorPlanScript = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")

## Intenta reparar conexiones de corredor obligatorias que hayan fallado en AStarCarver.
## Retorna Dictionary { "success": bool, "corridor_res": CorridorCarveResult, "repairs_applied": Array, "seed_used": int }
static func repair_missing_corridors(
	grid: CellGrid,
	rooms: Array[RoomData],
	entrance_pairs: Array,
	connections: Array,
	initial_res: CorridorCarveResult,
	repair_seed: int,
	corridor_plan: _CorridorPlanScript,
	config: DungeonConfig = null
) -> Dictionary:
	if corridor_plan == null:
		assert(false, "[CorridorConnectivityRepair] Contract violation: corridor_plan is mandatory.")
		push_error("[CorridorConnectivityRepair] Contract violation: corridor_plan is mandatory.")
		return {
			"success": false,
			"corridor_res": initial_res,
			"repairs_applied": [],
			"seed_used": repair_seed
		}

	if initial_res == null or initial_res.is_valid:
		return {
			"success": true,
			"corridor_res": initial_res,
			"repairs_applied": [],
			"seed_used": repair_seed
		}

	var cfg := config
	if cfg == null:
		cfg = DungeonConfig.new()

	var journal = _CellGridJournalScript.new()
	var repairs_applied: Array = []

	var conn_map: Dictionary = {}
	for conn in connections:
		if conn != null:
			conn_map[conn.id] = conn

	var pair_map: Dictionary = {}
	for pair in entrance_pairs:
		if pair != null:
			pair_map[pair.connection_id] = pair

	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	var width: int = grid.width
	var height: int = grid.height

	# 5. Reintentar cada conexión requerida fallida dentro del presupuesto de reparaciones
	var max_repairs: int = cfg.corridor_max_repair_attempts if ("corridor_max_repair_attempts" in cfg) else 3
	var attempts: int = 0
	var all_repaired: bool = true

	# Construir un nuevo resultado acumulativo a partir de los paths y diagnósticos ya tallados con éxito
	var new_res = _CorridorCarveResultScript.new()
	for p in initial_res.paths:
		new_res.add_path(p)

	# Mapear diagnósticos iniciales para preservar campos de trazabilidad
	var initial_diag_map: Dictionary = {}
	for d in initial_res.diagnostics:
		if d.has("connection_id"):
			initial_diag_map[d["connection_id"]] = d.duplicate(true)

	for failed_id in initial_res.failed_connection_ids:
		var pair = pair_map.get(failed_id, null)
		var conn = conn_map.get(failed_id, null)

		if pair == null or conn == null:
			all_repaired = false
			break

		var is_req: bool = conn.is_required if ("is_required" in conn) else true
		if not is_req:
			# Opcional: ignorar fallo si no es obligatoria
			continue

		attempts += 1
		if attempts > max_repairs:
			all_repaired = false
			var budget_diag: Dictionary = initial_diag_map.get(failed_id, {})
			budget_diag["connection_id"] = failed_id
			budget_diag["repair_attempted"] = true
			budget_diag["repair_success"] = false
			budget_diag["status"] = "FAILED"
			budget_diag["reason"] = "REPAIR_FAILED: SEARCH_BUDGET_EXCEEDED"
			budget_diag["termination_reason"] = "SEARCH_BUDGET_EXCEEDED"
			new_res.add_failure(failed_id, "REPAIR_FAILED: SEARCH_BUDGET_EXCEEDED", budget_diag)
			break

		var req: _CorridorRequestScript = corridor_plan.get_request_for_connection(failed_id)
		if req == null:
			all_repaired = false
			break

		# Estrategia 1: Reintento con ancho relajado a 1 celda (evita colisiones de widening)
		var relaxed_cfg: DungeonConfig = cfg.duplicate_config() if cfg.has_method("duplicate_config") else cfg.duplicate()
		relaxed_cfg.corridor_width = 1

		var res: Dictionary = _carve_with_journal(grid, rooms, room_map, req, relaxed_cfg, width, height, journal)

		var diag: Dictionary = initial_diag_map.get(req.connection_id, {})
		diag["connection_id"] = req.connection_id
		diag["room_a_id"] = req.room_a_id
		diag["room_b_id"] = req.room_b_id
		diag["role"] = req.corridor_role
		diag["routing_preference"] = req.routing_preference
		diag["preferred_length"] = req.preferred_length
		diag["repair_attempted"] = true
		diag["expanded_states"] = res.get("expanded_states", 0)
		diag["elapsed_ms"] = res.get("elapsed_ms", 0.0)
		diag["strategy"] = "Repair"

		if res["success"]:
			var path: CorridorPath = res["path"]
			diag["repair_success"] = true
			diag["status"] = "REPAIRED"
			diag["actual_length"] = path.centerline_cells.size()
			diag["turn_count"] = path.turn_count
			diag["cost"] = path.cost
			diag["termination_reason"] = "SUCCESS"
			new_res.add_path(path, diag)
			repairs_applied.append("repaired_conn_%d_width1" % req.connection_id)
		else:
			all_repaired = false
			diag["repair_success"] = false
			diag["status"] = "FAILED"
			var fail_reason: String = "REPAIR_FAILED: " + res.get("reason", "NO_PATH")
			diag["reason"] = fail_reason
			diag["termination_reason"] = res.get("termination_reason", "NO_PATH")
			new_res.add_failure(req.connection_id, fail_reason, diag)
			break

	if all_repaired and new_res.failed_connection_ids.is_empty():
		journal.commit()
		new_res.is_valid = true
		return {
			"success": true,
			"corridor_res": new_res,
			"repairs_applied": repairs_applied,
			"seed_used": repair_seed
		}

	# Rollback completo si alguna conexión obligatoria no pudo repararse
	journal.rollback(grid)
	new_res.is_valid = false
	return {
		"success": false,
		"corridor_res": new_res,
		"repairs_applied": [],
		"seed_used": repair_seed
	}

## Realiza el tallado de una petición registrando todas las celdas afectadas en el journal previo a su mutación.
## Utiliza Direction-Aware A* acotado respetando la intención y ancho 1 celda.
static func _carve_with_journal(
	grid: CellGrid,
	rooms: Array[RoomData],
	room_map: Dictionary,
	req: CorridorRequest,
	config: DungeonConfig,
	grid_width: int,
	grid_height: int,
	journal: RefCounted
) -> Dictionary:
	var start_pos := req.start
	var goal_pos := req.goal

	if not grid.is_in_bounds(start_pos):
		return {"success": false, "reason": "START_OUT_OF_BOUNDS", "termination_reason": "START_OUT_OF_BOUNDS"}
	if not grid.is_in_bounds(goal_pos):
		return {"success": false, "reason": "GOAL_OUT_OF_BOUNDS", "termination_reason": "GOAL_OUT_OF_BOUNDS"}

	# Ejecutar Direction-Aware A* con límites de tiempo y estados respetando intención
	var astar_res: Dictionary = _AStarCarverScript._find_direction_aware_path(
		grid, rooms, room_map, req, config, grid_width, grid_height
	)

	if not astar_res.get("success", false):
		return {
			"success": false,
			"reason": astar_res.get("reason", "NO_PATH"),
			"expanded_states": astar_res.get("expanded_states", 0),
			"elapsed_ms": astar_res.get("elapsed_ms", 0.0),
			"termination_reason": astar_res.get("termination_reason", "NO_PATH")
		}

	var centerline: Array[Vector2i] = astar_res["centerline"]

	var val_error: String = _AStarCarverScript._validate_centerline(
		centerline, start_pos, goal_pos, grid, rooms, req.room_a_id, req.room_b_id
	)
	if not val_error.is_empty():
		return {
			"success": false,
			"reason": val_error,
			"expanded_states": astar_res.get("expanded_states", 0),
			"elapsed_ms": astar_res.get("elapsed_ms", 0.0),
			"termination_reason": val_error
		}

	var candidate_carved_cells: Array[Vector2i] = []
	var seen_cells: Dictionary = {}

	var boundary_cells := [req.start_boundary, req.goal_boundary]
	for bc in boundary_cells:
		if grid.is_in_bounds(bc) and not seen_cells.has(bc):
			candidate_carved_cells.append(bc)
			seen_cells[bc] = true

	for p in centerline:
		if not seen_cells.has(p):
			candidate_carved_cells.append(p)
			seen_cells[p] = true

	for cell in candidate_carved_cells:
		if not grid.is_in_bounds(cell):
			return {"success": false, "reason": "OUT_OF_BOUNDS", "termination_reason": "OUT_OF_BOUNDS"}
		var cell_type := grid.get_cell(cell)
		if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
			return {"success": false, "reason": "BLOCKED_CELL", "termination_reason": "BLOCKED_CELL"}

	# Commit atómico con Journaling
	var reused_count: int = 0
	var total_cost: float = 0.0

	for cell in candidate_carved_cells:
		journal.record_cell(grid, cell)
		var current_type := grid.get_cell(cell)
		if current_type == CellGrid.CellType.CORRIDOR:
			reused_count += 1
		else:
			grid.set_cell(cell, CellGrid.CellType.CORRIDOR)
		total_cost += 1.0

	var room_a: RoomData = room_map.get(req.room_a_id, null)
	var room_b: RoomData = room_map.get(req.room_b_id, null)

	var inner_a: Vector2i = req.start_inner if req.start_inner != Vector2i.ZERO else (req.start_boundary - req.start_direction)
	var inner_b: Vector2i = req.goal_inner if req.goal_inner != Vector2i.ZERO else (req.goal_boundary - req.goal_direction)
	_AStarCarverScript._connect_inner_to_room_floor(grid, room_a, inner_a, journal)
	_AStarCarverScript._connect_inner_to_room_floor(grid, room_b, inner_b, journal)

	var metrics: Dictionary = _AStarCarverScript.compute_path_metrics(centerline)

	var path = _CorridorPathScript.new(
		req.connection_id,
		req.room_a_id,
		req.room_b_id,
		centerline,
		candidate_carved_cells,
		total_cost,
		reused_count,
		metrics["turn_count"],
		metrics["longest_straight_run"],
		"Repair"
	)
	path.straight_run_count = metrics["straight_run_count"]
	path.expanded_states = astar_res.get("expanded_states", 0)
	path.elapsed_ms = astar_res.get("elapsed_ms", 0.0)
	path.termination_reason = "SUCCESS"

	return {
		"success": true,
		"path": path,
		"expanded_states": astar_res.get("expanded_states", 0),
		"elapsed_ms": astar_res.get("elapsed_ms", 0.0),
		"termination_reason": "SUCCESS"
	}
