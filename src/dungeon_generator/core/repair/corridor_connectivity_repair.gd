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

## Intenta reparar conexiones de corredor obligatorias que hayan fallado en AStarCarver.
## Retorna Dictionary { "success": bool, "corridor_res": CorridorCarveResult, "repairs_applied": Array, "seed_used": int }
static func repair_missing_corridors(
	grid: CellGrid,
	rooms: Array[RoomData],
	entrance_pairs: Array,
	connections: Array,
	initial_res: CorridorCarveResult,
	repair_seed: int,
	config: DungeonConfig = null
) -> Dictionary:
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

	# Construir un nuevo resultado acumulativo a partir de los paths ya tallados con éxito
	var new_res = _CorridorCarveResultScript.new()
	for p in initial_res.paths:
		new_res.add_path(p)

	# Reintentar cada conexión requerida fallida
	var all_repaired: bool = true

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

		var req := _CorridorRequestScript.from_entrance_pair(pair, is_req)
		if req == null:
			all_repaired = false
			break

		# Estrategia 1: Reintento con ancho estricto de 1 celda (evita colisiones de widening)
		var relaxed_cfg := cfg.duplicate()
		relaxed_cfg.corridor_width = 1

		# Crear grafo AStar con el estado actual del grid
		var astar := _AStarCarverScript._build_base_astar_graph(grid, relaxed_cfg)
		var res: Dictionary = _carve_with_journal(grid, rooms, room_map, req, relaxed_cfg, astar, width, height, journal)

		if res["success"]:
			var path: CorridorPath = res["path"]
			new_res.add_path(path, {
				"connection_id": req.connection_id,
				"status": "REPAIRED",
				"cost": path.cost
			})
			repairs_applied.append("repaired_conn_%d_width1" % req.connection_id)
		else:
			all_repaired = false
			new_res.add_failure(req.connection_id, "REPAIR_FAILED: " + res.get("reason", "NO_PATH"))
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
	return {
		"success": false,
		"corridor_res": initial_res,
		"repairs_applied": [],
		"seed_used": repair_seed
	}

## Realiza el tallado de una petición registrando todas las celdas afectadas en el journal previo a su mutación.
static func _carve_with_journal(
	grid: CellGrid,
	rooms: Array[RoomData],
	room_map: Dictionary,
	req: CorridorRequest,
	config: DungeonConfig,
	astar: AStar2D,
	grid_width: int,
	grid_height: int,
	journal: RefCounted
) -> Dictionary:
	var start_pos := req.start
	var goal_pos := req.goal

	if not grid.is_in_bounds(start_pos):
		return {"success": false, "reason": "START_OUT_OF_BOUNDS"}
	if not grid.is_in_bounds(goal_pos):
		return {"success": false, "reason": "GOAL_OUT_OF_BOUNDS"}

	var start_id: int = _AStarCarverScript._get_cell_id(start_pos, grid_width)
	var goal_id: int = _AStarCarverScript._get_cell_id(goal_pos, grid_width)

	var modified_nodes: Dictionary = {}
	_AStarCarverScript._apply_room_isolation_weights(astar, rooms, req.room_a_id, req.room_b_id, config, grid_width, modified_nodes)

	var orig_start_weight: float = astar.get_point_weight_scale(start_id)
	var orig_goal_weight: float = astar.get_point_weight_scale(goal_id)
	astar.set_point_weight_scale(start_id, 1.0)
	astar.set_point_weight_scale(goal_id, 1.0)

	var point_path: PackedVector2Array = astar.get_point_path(start_id, goal_id)

	astar.set_point_weight_scale(start_id, orig_start_weight)
	astar.set_point_weight_scale(goal_id, orig_goal_weight)
	_AStarCarverScript._restore_modified_weights(astar, modified_nodes)

	if point_path.is_empty():
		return {"success": false, "reason": "NO_PATH"}

	var centerline: Array[Vector2i] = []
	for p_vec in point_path:
		centerline.append(Vector2i(int(p_vec.x), int(p_vec.y)))

	var val_error: String = _AStarCarverScript._validate_centerline(centerline, start_pos, goal_pos, grid, rooms, req.room_a_id, req.room_b_id)
	if not val_error.is_empty():
		return {"success": false, "reason": val_error}

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
			return {"success": false, "reason": "OUT_OF_BOUNDS"}
		var cell_type := grid.get_cell(cell)
		if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
			return {"success": false, "reason": "BLOCKED_CELL"}

	# Commit con Journaling
	var reused_count: int = 0
	var total_cost: float = 0.0

	for cell in candidate_carved_cells:
		journal.record_cell(grid, cell)
		var current_type := grid.get_cell(cell)
		if current_type == CellGrid.CellType.CORRIDOR:
			reused_count += 1
		else:
			grid.set_cell(cell, CellGrid.CellType.CORRIDOR)
			var cid: int = _AStarCarverScript._get_cell_id(cell, grid_width)
			astar.set_point_weight_scale(cid, 1.0)
		total_cost += 1.0

	var room_a: RoomData = room_map.get(req.room_a_id, null)
	var room_b: RoomData = room_map.get(req.room_b_id, null)

	var inner_a: Vector2i = req.start_boundary - req.start_direction
	var inner_b: Vector2i = req.goal_boundary - req.goal_direction
	_AStarCarverScript._connect_inner_to_room_floor(grid, room_a, inner_a, journal)
	_AStarCarverScript._connect_inner_to_room_floor(grid, room_b, inner_b, journal)

	if room_a != null:
		if not room_a.connections.has(req.start_boundary):
			room_a.connections.append(req.start_boundary)
		if not room_a.connected_room_ids.has(req.room_b_id):
			room_a.connected_room_ids.append(req.room_b_id)

	if room_b != null:
		if not room_b.connections.has(req.goal_boundary):
			room_b.connections.append(req.goal_boundary)
		if not room_b.connected_room_ids.has(req.room_a_id):
			room_b.connected_room_ids.append(req.room_a_id)

	var path = _CorridorPathScript.new(
		req.connection_id,
		req.room_a_id,
		req.room_b_id,
		centerline,
		candidate_carved_cells,
		total_cost,
		reused_count
	)

	return {
		"success": true,
		"path": path
	}
