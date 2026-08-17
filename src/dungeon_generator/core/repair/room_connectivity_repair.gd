class_name RoomConnectivityRepair
extends RefCounted

## Reparador inteligente y atómico de conectividad interna para habitaciones (Fase 6.1.1).
## Conecta islas secundarias a la región principal determinista respetando los límites de la habitación
## y garantiza rollback exacto mediante CellGridJournal ante cualquier fallo.

const _CellGridJournalScript = preload("res://src/dungeon_generator/core/repair/cell_grid_journal.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")

## Repara la conectividad interna de una habitación fragmentada.
## Retorna un Dictionary con { "success": bool, "repairs_applied": Array, "details": Dictionary, "seed_used": int }
static func repair_room_internal_connectivity(
	grid: CellGrid,
	room: RoomData,
	diag: Dictionary,
	repair_seed: int,
	_max_attempts: int = 2
) -> Dictionary:
	if grid == null or room == null:
		return {
			"success": false,
			"repairs_applied": [],
			"details": {"reason": "NULL_INPUT"},
			"seed_used": repair_seed
		}

	var regions: Array = diag.get("regions", [])
	if regions.size() <= 1:
		return {
			"success": true,
			"repairs_applied": [],
			"details": {"reason": "ALREADY_VALID"},
			"seed_used": repair_seed
		}

	var journal = _CellGridJournalScript.new()
	var repairs_applied: Array = []

	# 1. Identificar la región principal determinista
	var main_region_idx: int = _select_main_region_index(grid, room, regions)
	if main_region_idx < 0 or main_region_idx >= regions.size():
		journal.rollback(grid)
		return {
			"success": false,
			"repairs_applied": [],
			"details": {"reason": "NO_MAIN_REGION"},
			"seed_used": repair_seed
		}

	var main_region: Array = regions[main_region_idx]
	var main_cells_set: Dictionary = {}
	for c in main_region:
		main_cells_set[c] = true

	# 2. Conectar cada isla secundaria a la región principal
	var connection_failed: bool = false

	for idx in range(regions.size()):
		if idx == main_region_idx:
			continue

		var island: Array = regions[idx]
		if island.is_empty():
			continue

		# Buscar el par de celdas más cercano entre la isla y la región principal acumulada
		var best_pair := _find_closest_cell_pair(island, main_cells_set)
		var start_pt: Vector2i = best_pair["island_cell"]
		var goal_pt: Vector2i = best_pair["main_cell"]

		# Trazar camino A* restringido al interior de room.rect
		var path: Array[Vector2i] = _find_path_inside_room(grid, room.rect, start_pt, goal_pt)
		if path.is_empty():
			connection_failed = true
			break

		# Tallar el camino como FLOOR registrando en el journal
		for pt in path:
			if grid.is_in_bounds(pt):
				journal.record_cell(grid, pt)
				grid.set_cell(pt, CellGrid.CellType.FLOOR)
				main_cells_set[pt] = true

		for pt in island:
			main_cells_set[pt] = true

		repairs_applied.append("connect_island_%d_to_main" % idx)

	# 3. Revalidación formal de la habitación
	var post_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, room)

	if not connection_failed and post_val["is_valid"]:
		journal.commit()
		return {
			"success": true,
			"repairs_applied": repairs_applied,
			"details": {
				"room_id": room.id,
				"regions_repaired": regions.size() - 1
			},
			"seed_used": repair_seed
		}

	# 4. Rollback total si falló la conexión o la revalidación
	journal.rollback(grid)
	return {
		"success": false,
		"repairs_applied": [],
		"details": {
			"room_id": room.id,
			"reason": "VALIDATION_FAILED_AFTER_REPAIR",
			"post_val": post_val
		},
		"seed_used": repair_seed
	}

## Selecciona el índice de la región principal según las prioridades estrictas:
## 1) Contiene el centro de la sala si es transitable.
## 2) Mayor número de celdas (size).
## 3) Menor coordenada mínima lexicográfica (y, x).
static func _select_main_region_index(grid: CellGrid, room: RoomData, regions: Array) -> int:
	if regions.is_empty():
		return -1

	var center := room.get_center()

	# Prioridad 1: Centro de la habitación
	if grid.is_walkable(center):
		for i in range(regions.size()):
			var reg: Array = regions[i]
			if reg.has(center):
				return i

	# Prioridad 2 y 3: Mayor tamaño y desempate lexicográfico
	var best_idx: int = 0
	var best_size: int = -1
	var best_lex_key: int = 999999999

	for i in range(regions.size()):
		var reg: Array = regions[i]
		var size: int = reg.size()
		var min_lex_key: int = _get_min_lexicographical_key(reg)

		if size > best_size:
			best_size = size
			best_lex_key = min_lex_key
			best_idx = i
		elif size == best_size:
			if min_lex_key < best_lex_key:
				best_lex_key = min_lex_key
				best_idx = i

	return best_idx

## Calcula la clave lexicográfica mínima (y * 100000 + x) de las celdas de una región.
static func _get_min_lexicographical_key(region: Array) -> int:
	var min_k: int = 999999999
	for c: Vector2i in region:
		var k: int = c.y * 100000 + c.x
		if k < min_k:
			min_k = k
	return min_k

## Encuentra el par de celdas más cercano entre una isla y la región principal con orden determinista.
static func _find_closest_cell_pair(island: Array, main_cells: Dictionary) -> Dictionary:
	var best_dist: int = 999999
	var best_island_pt := Vector2i.ZERO
	var best_main_pt := Vector2i.ZERO
	var best_lex_tie: int = 999999999

	for i_pt: Vector2i in island:
		for m_pt: Vector2i in main_cells.keys():
			var dist: int = absi(i_pt.x - m_pt.x) + absi(i_pt.y - m_pt.y)
			var tie_key: int = (i_pt.y * 100000 + i_pt.x) + (m_pt.y * 1000 + m_pt.x)

			if dist < best_dist:
				best_dist = dist
				best_island_pt = i_pt
				best_main_pt = m_pt
				best_lex_tie = tie_key
			elif dist == best_dist:
				if tie_key < best_lex_tie:
					best_lex_tie = tie_key
					best_island_pt = i_pt
					best_main_pt = m_pt

	return {
		"island_cell": best_island_pt,
		"main_cell": best_main_pt,
		"distance": best_dist
	}

## Búsqueda de camino A* restringida estrictamente a los límites de room.rect.
static func _find_path_inside_room(
	grid: CellGrid,
	rect: Rect2i,
	start_pos: Vector2i,
	goal_pos: Vector2i
) -> Array[Vector2i]:
	if start_pos == goal_pos:
		return [start_pos]

	var astar := AStar2D.new()
	var width: int = rect.size.x
	var height: int = rect.size.y

	for dy in range(height):
		for dx in range(width):
			var pos := Vector2i(rect.position.x + dx, rect.position.y + dy)
			var id: int = dy * width + dx
			astar.add_point(id, Vector2(pos.x, pos.y))

			var cell_type := grid.get_cell(pos)
			if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
				astar.set_point_disabled(id, true)
			elif grid.is_walkable(pos):
				astar.set_point_weight_scale(id, 1.0)
			else:
				# Muros internos: coste 5.0 para preferir atravesar el menor número de muros
				astar.set_point_weight_scale(id, 5.0)

	# Conectar vecinos cardinales dentro de room.rect
	for dy in range(height):
		for dx in range(width):
			var id: int = dy * width + dx
			if dx + 1 < width:
				var right_id: int = dy * width + (dx + 1)
				astar.connect_points(id, right_id)
			if dy + 1 < height:
				var down_id: int = (dy + 1) * width + dx
				astar.connect_points(id, down_id)

	var start_id: int = (start_pos.y - rect.position.y) * width + (start_pos.x - rect.position.x)
	var goal_id: int = (goal_pos.y - rect.position.y) * width + (goal_pos.x - rect.position.x)

	if not astar.has_point(start_id) or not astar.has_point(goal_id):
		return []

	var point_path: PackedVector2Array = astar.get_point_path(start_id, goal_id)
	var result: Array[Vector2i] = []
	for p in point_path:
		result.append(Vector2i(int(p.x), int(p.y)))

	return result
