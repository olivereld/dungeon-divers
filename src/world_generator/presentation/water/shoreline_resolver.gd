class_name ShorelineResolver
extends RefCounted

## Responsabilidad Única: calcular el campo de distancia euclidiana con signo
## (Shoreline Distance Field) a partir de la topología de water_cells.
##
## Pipeline interno:
##   WaterTopology  ->  aristas de frontera
##                  ->  polilineas encadenadas orientadas
##                  ->  suavizado Chaikin (curvas organicas)
##                  ->  desplazamiento organico determinista (Block B)
##                  ->  signo geometrico via Winding Number (Block A)
##                  ->  segmentos finales con indexacion espacial (bucketing)
##                  ->  PackedFloat32Array  (1 float por vertice de grilla)
##
## Contrato de salida por vertice:
##   sdf[y*w + x] = clamp(0.5 + signed_dist / (2 * MAX_QUERY_DIST), 0.0, 1.0)
##     > 0.5  ->  interior de agua
##     = 0.5  ->  linea de costa exacta
##     < 0.5  ->  tierra seca bajo el talud

const MAX_QUERY_DIST: float = 3.0
const DEFAULT_ORGANIC_AMPLITUDE: float = 0.12

class ContourResult:
	var segments: Array[PackedVector2Array] = []
	var closed_polylines: Array[PackedVector2Array] = []
	var seg_is_closed: PackedByteArray = PackedByteArray()

## Punto de entrada publico: devuelve el SDF completo de la grilla W x H.
static func compute(
		water_cells: Dictionary,
		topo: WaterTopology,
		w: int,
		h: int,
		seed_val: int = 0,
		displacement_amplitude: float = DEFAULT_ORGANIC_AMPLITUDE,
		shoreline_offset: float = -0.3
	) -> PackedFloat32Array:

	var sdf: PackedFloat32Array = PackedFloat32Array()
	sdf.resize(w * h)

	if water_cells.is_empty():
		sdf.fill(0.0)
		return sdf

	var contour: ContourResult = _build_contour_data(topo, seed_val, displacement_amplitude)
	var segments: Array[PackedVector2Array] = contour.segments
	var closed_polylines: Array[PackedVector2Array] = contour.closed_polylines
	var seg_is_closed: PackedByteArray = contour.seg_is_closed

	if segments.is_empty():
		for y in range(h):
			for x in range(w):
				sdf[y * w + x] = 1.0 if water_cells.has(Vector2i(x, y)) else 0.0
		return sdf

	var buckets: Dictionary = _build_buckets(segments)
	var max_dist_sq: float = MAX_QUERY_DIST * MAX_QUERY_DIST

	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var v2d := Vector2(float(x), float(y))

			var min_dist_sq: float = max_dist_sq
			var nearest_seg_idx: int = -1

			var bkey := Vector2i(int(floor(v2d.x / 4.0)), int(floor(v2d.y / 4.0)))
			if buckets.has(bkey):
				for s_idx: int in buckets[bkey]:
					var seg: PackedVector2Array = segments[s_idx]
					var d_sq: float = _dist_sq_point_to_seg(v2d, seg[0], seg[1])
					if d_sq < min_dist_sq:
						min_dist_sq = d_sq
						nearest_seg_idx = s_idx

			var sign_val: float = 1.0
			if nearest_seg_idx != -1 and min_dist_sq < max_dist_sq:
				sign_val = _compute_sign(v2d, pos2i, closed_polylines, segments[nearest_seg_idx], seg_is_closed[nearest_seg_idx] == 1, water_cells)
			else:
				sign_val = 1.0 if water_cells.has(pos2i) else -1.0

			var signed_dist: float = sqrt(min_dist_sq) * sign_val
			signed_dist += shoreline_offset
			sdf[y * w + x] = clampf(0.5 + signed_dist / (2.0 * MAX_QUERY_DIST), 0.0, 1.0)

	# Segunda protección: celdas interiores de agua (con sus 4 vecinos cardinales
	# también siendo agua) deben quedar siempre estrictamente en el interior del SDF (1.0).
	# Esto impide que perturbaciones o aproximaciones numéricas del contorno
	# conviertan celdas sumergidas interiores en falsos agujeros visuales.
	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			if not water_cells.has(pos2i):
				continue
			var is_interior := true
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not water_cells.has(pos2i + off):
					is_interior = false
					break
			if is_interior:
				sdf[y * w + x] = maxf(sdf[y * w + x], 1.0)

	return sdf

## Compatibilidad: expone los segmentos suavizados
static func _build_smoothed_segments(topo: WaterTopology) -> Array[PackedVector2Array]:
	var res: ContourResult = _build_contour_data(topo, 0, 0.0)
	return res.segments

# ---------------------------------------------------------------------------
# Privados: encadenamiento de polilineas + Chaikin + Desplazamiento Organico
# ---------------------------------------------------------------------------

static func _build_contour_data(
		topo: WaterTopology,
		seed_val: int,
		amplitude: float
	) -> ContourResult:

	var res := ContourResult.new()
	if topo == null:
		return res

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
		return res

	var start_map: Dictionary = {}
	for i in range(directed.size()):
		var p0: Vector2 = directed[i][0]
		if not start_map.has(p0):
			start_map[p0] = []
		start_map[p0].append(i)

	var used: PackedByteArray = PackedByteArray()
	used.resize(directed.size())

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

		var smooth: Array[Vector2]
		if chain.size() >= 3:
			smooth = _chaikin(chain, is_closed, 2)
		else:
			smooth = chain.duplicate()

		if amplitude > 0.001 and smooth.size() >= 2:
			smooth = _displace_organically(smooth, is_closed, amplitude, seed_val)

		var m: int = smooth.size()
		if is_closed and m >= 3:
			res.closed_polylines.append(PackedVector2Array(smooth))
			for j: int in range(m):
				var pA: Vector2 = smooth[j]
				var pB: Vector2 = smooth[(j + 1) % m]
				res.segments.append(PackedVector2Array([pA, pB]))
				res.seg_is_closed.append(1)
		else:
			for j: int in range(m - 1):
				var pA: Vector2 = smooth[j]
				var pB: Vector2 = smooth[j + 1]
				res.segments.append(PackedVector2Array([pA, pB]))
				res.seg_is_closed.append(0)

	return res

## Block B: Desplazamiento organico determinista a lo largo de las normales de la curva
static func _displace_organically(
		pts: Array[Vector2],
		is_closed: bool,
		amplitude: float,
		seed_val: int
	) -> Array[Vector2]:

	var n: int = pts.size()
	if amplitude <= 0.0001 or n < 2:
		return pts

	var result: Array[Vector2] = []
	result.resize(n)

	var seed_f: float = float((seed_val * 1664525 + 1013904223) & 0x7FFFFFFF) * 0.000001

	for i in range(n):
		var p: Vector2 = pts[i]

		var tangent: Vector2
		if is_closed:
			var prev_p: Vector2 = pts[(i - 1 + n) % n]
			var next_p: Vector2 = pts[(i + 1) % n]
			tangent = (next_p - prev_p).normalized()
		else:
			if i == 0:
				tangent = (pts[1] - pts[0]).normalized()
			elif i == n - 1:
				tangent = (pts[n - 1] - pts[n - 2]).normalized()
			else:
				tangent = (pts[i + 1] - pts[i - 1]).normalized()

		var normal := Vector2(-tangent.y, tangent.x)

		# Taper en extremos de polilineas abiertas para mantener bordes anclados
		var taper: float = 1.0
		if not is_closed:
			if i == 0 or i == n - 1:
				taper = 0.0
			elif i == 1 or i == n - 2:
				taper = 0.5

		var s: float = p.x * 0.618 + p.y * 0.786 + seed_f
		var disp: float = (sin(s * 1.85) * 0.65 + cos(s * 3.41 + 1.1) * 0.35) * amplitude * taper
		result[i] = p + normal * disp

	return result

# ---------------------------------------------------------------------------
# Block A: Determinacion de signo via Winding Number y orientacion de aristas
# ---------------------------------------------------------------------------

static func _compute_sign(
		point: Vector2,
		pos2i: Vector2i,
		closed_polylines: Array[PackedVector2Array],
		nearest_seg: PackedVector2Array,
		is_closed_seg: bool,
		water_cells: Dictionary
	) -> float:

	# water_cells es la autoridad hidráulica absoluta.
	# Una celda marcada como agua nunca puede ser descartada
	# por una interpretación geométrica del SDF.
	if water_cells.has(pos2i):
		return 1.0

	if not closed_polylines.is_empty():
		var total_wn: int = 0
		for poly in closed_polylines:
			total_wn += _winding_number(point, poly)

		if total_wn != 0:
			return 1.0 # Dentro de un bucle cerrado de agua
		elif is_closed_seg:
			return -1.0 # Fuera de todos los bucles cerrados y cerca de un contorno de lago cerrado

	# Para contornos abiertos (e.g. rios que cruzan la grilla), usar orientacion local de la arista
	var d: Vector2 = nearest_seg[1] - nearest_seg[0]
	var cross: float = d.x * (point.y - nearest_seg[0].y) - d.y * (point.x - nearest_seg[0].x)
	var seg_len: float = d.length()
	var normalized_cross: float = cross / maxf(seg_len, 0.0001)

	if absf(normalized_cross) > 0.05:
		return 1.0 if cross > 0.0 else -1.0

	return -1.0

static func _winding_number(point: Vector2, poly: PackedVector2Array) -> int:
	var wn: int = 0
	var n: int = poly.size()
	for i in range(n):
		var p1: Vector2 = poly[i]
		var p2: Vector2 = poly[(i + 1) % n]
		if p1.y <= point.y:
			if p2.y > point.y:
				if (p2.x - p1.x) * (point.y - p1.y) - (point.x - p1.x) * (p2.y - p1.y) > 0.0:
					wn += 1
		else:
			if p2.y <= point.y:
				if (p2.x - p1.x) * (point.y - p1.y) - (point.x - p1.x) * (p2.y - p1.y) < 0.0:
					wn -= 1
	return wn

# ---------------------------------------------------------------------------
# Privados: indexacion espacial y matematicas
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
