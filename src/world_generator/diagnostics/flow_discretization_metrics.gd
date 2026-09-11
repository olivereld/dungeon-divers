class_name FlowDiscretizationMetrics
extends RefCounted

## Métricas de diagnóstico cuantitativo para la discretización del Flow Field (D8).
## Mide patologías potenciales sin alterar ninguna decisión algorítmica.

const SCORE_TIE_EPSILON: float = 0.0001
const DIAGONAL_STREAK_WARN: int = 5
const CARDINAL_STREAK_WARN: int = 5
const MAX_TRACE_STEPS: int = 5000
const FLAT_AREA_MIN: int = 6
const SUSPICIOUS_FLAT_VARIANCE_MIN: float = 0.0005
const TIE_MAX_DOT_PRODUCT: float = 0.7071  # cos(45°) -> angle > 45° if dot < 0.7071

const D8_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]

static func measure(
	cells: Dictionary,
	flow_to: Dictionary,
	flow_vector: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	candidate_scores: Dictionary = {}
) -> Dictionary:
	var suspicious_ties: Array[Vector2i] = []
	var max_diagonal_streak_per_chain: Dictionary = {}
	var max_cardinal_streak_per_chain: Dictionary = {}
	var flagged_chains: Array[int] = []
	var chain_lengths: Dictionary = {}
	var unreachable_cells: Array[Vector2i] = []
	var suspicious_flat_regions: Array[Dictionary] = []

	# -------------------------------------------------------------------------
	# 1. Detección de bifurcaciones artificiales (suspicious_ties)
	# -------------------------------------------------------------------------
	if not candidate_scores.is_empty():
		for pos in candidate_scores:
			var candidates: Array = candidate_scores[pos]
			if candidates.size() < 2:
				continue

			var max_score: float = -INF
			for cand in candidates:
				var sc: float = float(cand.get("score", -INF))
				if sc > max_score:
					max_score = sc

			# Filtrar candidatos dentro del margen de empate
			var tied_candidates: Array = []
			for cand in candidates:
				var sc: float = float(cand.get("score", -INF))
				if sc >= max_score - SCORE_TIE_EPSILON:
					tied_candidates.append(cand)

			if tied_candidates.size() >= 2:
				var has_non_colinear_tie: bool = false
				for i in range(tied_candidates.size()):
					var n1: Vector2i = tied_candidates[i]["neighbor"]
					var d1 := Vector2(float(n1.x - pos.x), float(n1.y - pos.y)).normalized()
					for j in range(i + 1, tied_candidates.size()):
						var n2: Vector2i = tied_candidates[j]["neighbor"]
						var d2 := Vector2(float(n2.x - pos.x), float(n2.y - pos.y)).normalized()
						if d1.dot(d2) < TIE_MAX_DOT_PRODUCT:
							has_non_colinear_tie = true
							break
					if has_non_colinear_tie:
						break

				if has_non_colinear_tie:
					suspicious_ties.append(pos)

	# -------------------------------------------------------------------------
	# 2. Detección de rachas (streaks) diagonales / cardinales por cadena de flujo
	# -------------------------------------------------------------------------
	# Calcular in-degree de cada celda para identificar cabeceras/fuentes de cadena
	var in_degree: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if cells.has(pos):
				in_degree[pos] = 0

	for pos in flow_to:
		var nxt: Vector2i = flow_to[pos]
		if nxt != pos and in_degree.has(nxt):
			in_degree[nxt] = in_degree[nxt] + 1

	var chain_id: int = 0
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if not cells.has(start):
				continue
			if in_degree.get(start, 0) != 0:
				continue  # Solo iniciamos desde celdas fuente (sin upstream)

			chain_id += 1
			var curr: Vector2i = start
			var visited: Dictionary = {}
			var max_diag_streak: int = 0
			var max_card_streak: int = 0
			var cur_diag_streak: int = 0
			var cur_card_streak: int = 0
			var length: int = 0

			while true:
				if visited.has(curr):
					break
				visited[curr] = true

				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr:
					break

				length += 1
				var diff := nxt - curr
				var is_diag: bool = (diff.x != 0 and diff.y != 0)
				var is_card: bool = ((diff.x != 0 and diff.y == 0) or (diff.x == 0 and diff.y != 0))

				if is_diag:
					cur_diag_streak += 1
					cur_card_streak = 0
					if cur_diag_streak > max_diag_streak:
						max_diag_streak = cur_diag_streak
				elif is_card:
					cur_card_streak += 1
					cur_diag_streak = 0
					if cur_card_streak > max_card_streak:
						max_card_streak = cur_card_streak
				else:
					cur_diag_streak = 0
					cur_card_streak = 0

				curr = nxt

			max_diagonal_streak_per_chain[chain_id] = max_diag_streak
			max_cardinal_streak_per_chain[chain_id] = max_card_streak
			chain_lengths[chain_id] = length

			if max_diag_streak >= DIAGONAL_STREAK_WARN or max_card_streak >= CARDINAL_STREAK_WARN:
				flagged_chains.append(chain_id)

	# -------------------------------------------------------------------------
	# 3. Detección de componentes sin outlet (unreachable_cells)
	# -------------------------------------------------------------------------
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if not cells.has(start):
				continue

			var curr: Vector2i = start
			var visited_in_path: Dictionary = {}
			var reached_terminal: bool = false
			var steps: int = 0

			while steps < MAX_TRACE_STEPS:
				if visited_in_path.has(curr):
					# Ciclo detectado
					break
				visited_in_path[curr] = true

				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr:
					reached_terminal = true
					break

				curr = nxt
				steps += 1

			if not reached_terminal:
				unreachable_cells.append(start)

	# -------------------------------------------------------------------------
	# 4. Detección de flat areas extrañas (suspicious_flat_regions)
	# -------------------------------------------------------------------------
	var visited_flat: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos) or visited_flat.has(pos):
				continue

			var f_vec: Vector2 = flow_vector.get(pos, Vector2.ZERO)
			if f_vec != Vector2.ZERO or hydro.is_lake(pos):
				continue

			# Flood-fill del parche plano continuo
			var cluster: Array[Vector2i] = []
			var queue: Array[Vector2i] = [pos]
			visited_flat[pos] = true

			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				cluster.append(cur)

				for off in D8_NEIGHBORS:
					var nb: Vector2i = cur + off
					if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
						continue
					if not cells.has(nb) or visited_flat.has(nb):
						continue
					if hydro.is_lake(nb):
						continue
					var nb_fvec: Vector2 = flow_vector.get(nb, Vector2.ZERO)
					if nb_fvec == Vector2.ZERO:
						visited_flat[nb] = true
						queue.append(nb)

			var area: int = cluster.size()
			if area >= FLAT_AREA_MIN:
				# Calcular varianza de elevación sobre h_raw
				var sum_h: float = 0.0
				for p in cluster:
					var cell: WorldCell = cells[p]
					var h_val: float = cell.raw_height if cell.raw_height != 0.0 else cell.height
					sum_h += h_val
				var mean_h: float = sum_h / float(area)

				var sum_sq: float = 0.0
				for p in cluster:
					var cell: WorldCell = cells[p]
					var h_val: float = cell.raw_height if cell.raw_height != 0.0 else cell.height
					var diff: float = h_val - mean_h
					sum_sq += diff * diff
				var variance: float = sum_sq / float(area)

				if variance >= SUSPICIOUS_FLAT_VARIANCE_MIN:
					suspicious_flat_regions.append({
						"cells": cluster,
						"area": area,
						"height_variance": variance
					})

	return {
		"suspicious_ties": suspicious_ties,
		"max_diagonal_streak_per_chain": max_diagonal_streak_per_chain,
		"max_cardinal_streak_per_chain": max_cardinal_streak_per_chain,
		"flagged_chains": flagged_chains,
		"chain_lengths": chain_lengths,
		"unreachable_cells": unreachable_cells,
		"suspicious_flat_regions": suspicious_flat_regions
	}
