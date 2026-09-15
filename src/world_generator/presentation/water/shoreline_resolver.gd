class_name ShorelineResolver
extends RefCounted

## Responsabilidad Única: calcular el campo de distancia euclidiana con signo
## (Shoreline Distance Field) a partir de la topología de water_cells.
##
## Pipeline interno:
##   WaterTopology  ->  aristas de frontera
##                  ->  polilineas encadenadas orientadas
##                  ->  suavizado Chaikin (curvas organicas)
##                  ->  segmentos finales con indexacion espacial (bucketing)
##                  ->  PackedFloat32Array  (1 float por vertice de grilla)
##
## Contrato de salida por vertice:
##   sdf[y*w + x] = clamp(0.5 + signed_dist / (2 * MAX_QUERY_DIST), 0.0, 1.0)
##     > 0.5  ->  interior de agua
##     = 0.5  ->  linea de costa exacta
##     < 0.5  ->  tierra seca bajo el talud

const MAX_QUERY_DIST: float = 3.0

## Punto de entrada publico: devuelve el SDF completo de la grilla W x H.
static func compute(
		water_cells: Dictionary,
		topo: WaterTopology,
		w: int,
		h: int
	) -> PackedFloat32Array:

	var segments: Array[PackedVector2Array] = _build_smoothed_segments(topo)
	var buckets: Dictionary = _build_buckets(segments)
	var max_dist_sq: float = MAX_QUERY_DIST * MAX_QUERY_DIST

	var sdf: PackedFloat32Array = PackedFloat32Array()
	sdf.resize(w * h)

	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var is_water: bool = water_cells.has(pos2i)
			var v2d := Vector2(float(x), float(y))

			var min_dist_sq: float = max_dist_sq
			var bkey := Vector2i(int(floor(v2d.x / 4.0)), int(floor(v2d.y / 4.0)))
			if buckets.has(bkey):
				for s_idx: int in buckets[bkey]:
					var seg: PackedVector2Array = segments[s_idx]
					var d_sq: float = _dist_sq_point_to_seg(v2d, seg[0], seg[1])
					if d_sq < min_dist_sq:
						min_dist_sq = d_sq

			var signed_dist: float = sqrt(min_dist_sq) * (1.0 if is_water else -1.0)
			sdf[y * w + x] = clampf(0.5 + signed_dist / (2.0 * MAX_QUERY_DIST), 0.0, 1.0)

	return sdf

# ---------------------------------------------------------------------------
# Privados: encadenamiento de polilineas + suavizado Chaikin
# ---------------------------------------------------------------------------

static func _build_smoothed_segments(topo: WaterTopology) -> Array[PackedVector2Array]:
	if topo == null:
		return []

	var directed: Array[PackedVector2Array] = []
	for pos in topo.cell_edges:
		var edges: Array = topo.cell_edges[pos]
		var px := float(pos.x)
		var py := float(pos.y)
		if edges[0] == WaterTopology.EdgeType.SHORELINE or edges[0] == WaterTopology.EdgeType.EXTERIOR:
			directed.append(PackedVector2Array([Vector2(px - 0.5, py - 0.5), Vector2(px + 0.5, py - 0.5)]))
		if edges[1] == WaterTopology.EdgeType.SHORELINE or edges[1] == WaterTopology.EdgeType.EXTERIOR:
			directed.append(PackedVector2Array([Vector2(px + 0.5, py - 0.5), Vector2(px + 0.5, py + 0.5)]))
		if edges[2] == WaterTopology.EdgeType.SHORELINE or edges[2] == WaterTopology.EdgeType.EXTERIOR:
			directed.append(PackedVector2Array([Vector2(px + 0.5, py + 0.5), Vector2(px - 0.5, py + 0.5)]))
		if edges[3] == WaterTopology.EdgeType.SHORELINE or edges[3] == WaterTopology.EdgeType.EXTERIOR:
			directed.append(PackedVector2Array([Vector2(px - 0.5, py + 0.5), Vector2(px - 0.5, py - 0.5)]))

	if directed.is_empty():
		return []

	var start_map: Dictionary = {}
	for i in range(directed.size()):
		var p0: Vector2 = directed[i][0]
		if not start_map.has(p0):
			start_map[p0] = []
		start_map[p0].append(i)

	var used: PackedByteArray = PackedByteArray()
	used.resize(directed.size())
	var result: Array[PackedVector2Array] = []

	for start_idx: int in range(directed.size()):
		if used[start_idx] == 1:
			continue

		var chain: Array[Vector2] = [directed[start_idx][0]]
		var curr_idx: int = start_idx
		var is_closed: bool = false

		while true:
			used[curr_idx] = 1
			var next_pt: Vector2 = directed[curr_idx][1]
			if next_pt == chain[0]:
				is_closed = true
				break
			chain.append(next_pt)
			var found_next: int = -1
			if start_map.has(next_pt):
				for cand_idx: int in start_map[next_pt]:
					if used[cand_idx] == 0:
						found_next = cand_idx
						break
			if found_next != -1:
				curr_idx = found_next
			else:
				break

		if chain.size() >= 3:
			var smooth: Array[Vector2] = _chaikin(chain, is_closed, 2)
			var m: int = smooth.size()
			var seg_count: int = m if is_closed else m - 1
			for j: int in range(seg_count):
				var pA: Vector2 = smooth[j]
				var pB: Vector2 = smooth[(j + 1) % m] if is_closed else smooth[j + 1]
				result.append(PackedVector2Array([pA, pB]))
		else:
			for pt_idx: int in range(chain.size() - 1):
				result.append(PackedVector2Array([chain[pt_idx], chain[pt_idx + 1]]))
			if is_closed and chain.size() >= 2:
				result.append(PackedVector2Array([chain[chain.size() - 1], chain[0]]))

	return result

# ---------------------------------------------------------------------------
# Privados: indexacion espacial
# ---------------------------------------------------------------------------

static func _build_buckets(segments: Array[PackedVector2Array]) -> Dictionary:
	var buckets: Dictionary = {}
	for seg_idx in range(segments.size()):
		var seg: PackedVector2Array = segments[seg_idx]
		var min_bx: int = int(floor(minf(seg[0].x, seg[1].x) / 4.0))
		var max_bx: int = int(floor(maxf(seg[0].x, seg[1].x) / 4.0))
		var min_by: int = int(floor(minf(seg[0].y, seg[1].y) / 4.0))
		var max_by: int = int(floor(maxf(seg[0].y, seg[1].y) / 4.0))
		for by in range(min_by - 1, max_by + 2):
			for bx in range(min_bx - 1, max_bx + 2):
				var bkey := Vector2i(bx, by)
				if not buckets.has(bkey):
					buckets[bkey] = []
				buckets[bkey].append(seg_idx)
	return buckets

# ---------------------------------------------------------------------------
# Privados: matematica
# ---------------------------------------------------------------------------

static func _dist_sq_point_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return ap.length_squared()
	return p.distance_squared_to(a + ab * clampf(ap.dot(ab) / len_sq, 0.0, 1.0))

static func _chaikin(pts: Array[Vector2], is_closed: bool, iterations: int = 2) -> Array[Vector2]:
	var curr: Array[Vector2] = []
	curr.append_array(pts)
	for _it in range(iterations):
		var next_pts: Array[Vector2] = []
		var n: int = curr.size()
		if is_closed:
			for i in range(n):
				var p0: Vector2 = curr[i]
				var p1: Vector2 = curr[(i + 1) % n]
				next_pts.append(p0 * 0.75 + p1 * 0.25)
				next_pts.append(p0 * 0.25 + p1 * 0.75)
		else:
			if n < 3:
				return curr
			next_pts.append(curr[0])
			for i in range(n - 1):
				var p0: Vector2 = curr[i]
				var p1: Vector2 = curr[i + 1]
				next_pts.append(p0 * 0.75 + p1 * 0.25)
				next_pts.append(p0 * 0.25 + p1 * 0.75)
			next_pts.append(curr[n - 1])
		curr = next_pts
	return curr
