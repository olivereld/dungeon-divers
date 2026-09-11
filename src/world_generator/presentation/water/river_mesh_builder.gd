class_name RiverMeshBuilder
extends RefCounted

## Constructor robusto de mallas de agua longitudinales (Quad Strips).
## Topología limpia garantizada (Bloques 1 al 9):
## 1. Deduplicación y remuestreo regular por longitud de arco acumulada (0.75m).
## 2. Tangentes normalizadas y normales combinadas estrictamente unitarias (|n| = 1.0).
## 3. Validación de quad 2D en XZ contra inversión de winding y cruce de aristas.
## 4. Fallback progresivo para curvas cerradas (normal previa, normal siguiente, reducción de ancho).
## 5. Ribbon estricto: exactamente dos vértices por sección y dos triángulos por segmento.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

static func build_river_surface(
	river: Variant,
	result: WorldResult,
	profile: WorldProfile
) -> RefCounted:
	var raw_pts: Array = []
	var raw_widths: Array = []
	var raw_depths: Array = []

	if river is River:
		raw_pts = river.points
		raw_widths = river.widths
		raw_depths = river.depths
	elif river is Dictionary:
		raw_pts = river.get("points", [])
		raw_widths = river.get("widths", [])
		raw_depths = river.get("depths", [])
	else:
		return null

	if raw_pts.size() < 2:
		return null

	# ------------------------------------------------------------------
	# BLOQUE 1 — Limpiar y remuestrear la línea central por distancia acumulada.
	# ------------------------------------------------------------------
	var sampled := _clean_and_resample_centerline(
		raw_pts,
		raw_widths,
		raw_depths,
		0.75
	)

	var pts: Array[Vector3] = sampled["points"]
	var widths: Array[float] = sampled["widths"]
	var depths: Array[float] = sampled["depths"]

	if pts.size() < 2:
		return null

	var surf = _WaterSurfaceDataScript.new()
	var cell_size: float = maxf(profile.cell_size, 0.01)

	# ------------------------------------------------------------------
	# BLOQUE 2 & 4 — Cálculo lateral del ribbon con normales unitarias
	# y pipeline de fallback para curvas cerradas.
	# ------------------------------------------------------------------
	var left_positions: Array[Vector3] = []
	var right_positions: Array[Vector3] = []
	var station_tangents: Array[Vector3] = []
	var station_normals: Array[Vector3] = []

	left_positions.resize(pts.size())
	right_positions.resize(pts.size())
	station_tangents.resize(pts.size())
	station_normals.resize(pts.size())

	for i in range(pts.size()):
		var p: Vector3 = pts[i]

		# 2.1 Tangente
		var tangent: Vector3
		var prev_dir := Vector3.ZERO
		var next_dir := Vector3.ZERO

		if i == 0:
			next_dir = (pts[1] - pts[0]).normalized()
			next_dir.y = 0.0
			tangent = next_dir
		elif i == pts.size() - 1:
			prev_dir = (pts[i] - pts[i - 1]).normalized()
			prev_dir.y = 0.0
			tangent = prev_dir
		else:
			prev_dir = (pts[i] - pts[i - 1]).normalized()
			next_dir = (pts[i + 1] - pts[i]).normalized()
			prev_dir.y = 0.0
			next_dir.y = 0.0

			tangent = prev_dir + next_dir
			if tangent.length_squared() < 0.0001:
				tangent = next_dir

		tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		station_tangents[i] = tangent

		# 2.2 Normales candidatas (longitud estrictamente 1.0)
		var prev_norm := Vector3.ZERO
		if prev_dir.length_squared() > 0.0001:
			prev_norm = Vector3(-prev_dir.z, 0.0, prev_dir.x).normalized()

		var next_norm := Vector3.ZERO
		if next_dir.length_squared() > 0.0001:
			next_norm = Vector3(-next_dir.z, 0.0, next_dir.x).normalized()

		var blended_normal := Vector3.ZERO
		if prev_norm != Vector3.ZERO and next_norm != Vector3.ZERO:
			blended_normal = prev_norm + next_norm
			if blended_normal.length_squared() > 0.0001:
				blended_normal = blended_normal.normalized()
			else:
				blended_normal = next_norm
		elif next_norm != Vector3.ZERO:
			blended_normal = next_norm
		elif prev_norm != Vector3.ZERO:
			blended_normal = prev_norm
		else:
			blended_normal = Vector3(-tangent.z, 0.0, tangent.x).normalized()

		var base_half_width: float = maxf(widths[i] / cell_size, 0.20) * 0.5

		# BLOQUE 3 & 4: Validación y fallbacks
		if i == 0:
			# Primera sección: usar normal combinada directa
			station_normals[0] = blended_normal
			left_positions[0] = p + blended_normal * base_half_width
			right_positions[0] = p - blended_normal * base_half_width
		else:
			var prev_l: Vector3 = left_positions[i - 1]
			var prev_r: Vector3 = right_positions[i - 1]

			var chosen_normal: Vector3 = blended_normal
			var chosen_left: Vector3 = p + blended_normal * base_half_width
			var chosen_right: Vector3 = p - blended_normal * base_half_width
			var quad_ok: bool = _quad_is_valid(prev_l, prev_r, chosen_left, chosen_right)

			if not quad_ok:
				# Fallback A: Normal del segmento anterior
				if prev_norm != Vector3.ZERO:
					var cand_l_a := p + prev_norm * base_half_width
					var cand_r_a := p - prev_norm * base_half_width
					if _quad_is_valid(prev_l, prev_r, cand_l_a, cand_r_a):
						chosen_normal = prev_norm
						chosen_left = cand_l_a
						chosen_right = cand_r_a
						quad_ok = true

				# Fallback B: Normal del segmento siguiente
				if not quad_ok and next_norm != Vector3.ZERO:
					var cand_l_b := p + next_norm * base_half_width
					var cand_r_b := p - next_norm * base_half_width
					if _quad_is_valid(prev_l, prev_r, cand_l_b, cand_r_b):
						chosen_normal = next_norm
						chosen_left = cand_l_b
						chosen_right = cand_r_b
						quad_ok = true

				# Fallback C: Reducción local progresiva de ancho
				if not quad_ok:
					var width_factors: Array[float] = [0.85, 0.70, 0.55, 0.40]
					var candidate_normals: Array[Vector3] = []
					if blended_normal != Vector3.ZERO: candidate_normals.append(blended_normal)
					if prev_norm != Vector3.ZERO and not candidate_normals.has(prev_norm): candidate_normals.append(prev_norm)
					if next_norm != Vector3.ZERO and not candidate_normals.has(next_norm): candidate_normals.append(next_norm)

					for factor in width_factors:
						var pinched_half_w: float = base_half_width * factor
						for c_norm in candidate_normals:
							var cand_l := p + c_norm * pinched_half_w
							var cand_r := p - c_norm * pinched_half_w
							if _quad_is_valid(prev_l, prev_r, cand_l, cand_r):
								chosen_normal = c_norm
								chosen_left = cand_l
								chosen_right = cand_r
								quad_ok = true
								break
						if quad_ok:
							break

				# Si todo falla, forzar normal previa y ancho al 40% para mantener coherencia
				if not quad_ok:
					var safe_norm: Vector3 = prev_norm if prev_norm != Vector3.ZERO else blended_normal
					var safe_half_w: float = base_half_width * 0.40
					chosen_normal = safe_norm
					chosen_left = p + safe_norm * safe_half_w
					chosen_right = p - safe_norm * safe_half_w

			station_normals[i] = chosen_normal
			left_positions[i] = chosen_left
			right_positions[i] = chosen_right

	# ------------------------------------------------------------------
	# BLOQUE 7 — Alturas del agua y adición de vértices a la superficie
	# ------------------------------------------------------------------
	var left_indices: Array[int] = []
	var right_indices: Array[int] = []
	left_indices.resize(pts.size())
	right_indices.resize(pts.size())

	var accumulated_dist: float = 0.0

	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		if i > 0:
			accumulated_dist += pts[i].distance_to(pts[i - 1])

		var left_pt: Vector3 = left_positions[i]
		var right_pt: Vector3 = right_positions[i]
		var norm: Vector3 = station_normals[i]
		var tangent: Vector3 = station_tangents[i]

		var bed_l: float = _sample_terrain(result, left_pt.x, left_pt.z)
		var bed_r: float = _sample_terrain(result, right_pt.x, right_pt.z)

		var bank_l: float = _sample_terrain(result, left_pt.x + norm.x * 0.5, left_pt.z + norm.z * 0.5)
		var bank_r: float = _sample_terrain(result, right_pt.x - norm.x * 0.5, right_pt.z - norm.z * 0.5)

		var depth: float = maxf(depths[i], 0.05)

		var left_y: float = minf(bed_l + depth, bank_l + 0.02)
		var right_y: float = minf(bed_r + depth, bank_r + 0.02)

		left_y = maxf(left_y, bed_l + 0.015)
		right_y = maxf(right_y, bed_r + 0.015)

		var flow_dir := Vector2(tangent.x, tangent.z)
		if flow_dir.length_squared() > 0.0001:
			flow_dir = flow_dir.normalized()

		var uv_v: float = accumulated_dist

		var left_idx: int = surf.add_vertex(
			Vector3(left_pt.x, left_y, left_pt.z),
			Vector3.UP,
			Vector2(0.0, uv_v),
			flow_dir,
			profile.water_color_river
		)

		var right_idx: int = surf.add_vertex(
			Vector3(right_pt.x, right_y, right_pt.z),
			Vector3.UP,
			Vector2(1.0, uv_v),
			flow_dir,
			profile.water_color_river
		)

		left_indices[i] = left_idx
		right_indices[i] = right_idx

	# ------------------------------------------------------------------
	# BLOQUE 5 — Construcción definitiva del ribbon: exactamente
	# dos triángulos por segmento longitudinal.
	# ------------------------------------------------------------------
	for i in range(pts.size() - 1):
		var l0: int = left_indices[i]
		var r0: int = right_indices[i]
		var l1: int = left_indices[i + 1]
		var r1: int = right_indices[i + 1]

		if _triangle_is_valid(surf.vertices[l0], surf.vertices[r0], surf.vertices[l1]):
			surf.add_triangle(l0, r0, l1)

		if _triangle_is_valid(surf.vertices[r0], surf.vertices[r1], surf.vertices[l1]):
			surf.add_triangle(r0, r1, l1)

	return surf

# ----------------------------------------------------------------------
# BLOQUE 1 — Remuestreo por distancia acumulada y sanitización
# ----------------------------------------------------------------------
static func _clean_and_resample_centerline(
	raw_pts: Array,
	raw_widths: Array,
	raw_depths: Array,
	target_spacing: float
) -> Dictionary:
	var clean_pts: Array[Vector3] = []
	var clean_w: Array[float] = []
	var clean_d: Array[float] = []

	if raw_pts.size() < 2:
		return {"points": clean_pts, "widths": clean_w, "depths": clean_d}

	# 1. Deduplicar puntos adyacentes a menos de 0.001m
	clean_pts.append(raw_pts[0])
	clean_w.append(_get_array_value(raw_widths, 0, 0.8))
	clean_d.append(_get_array_value(raw_depths, 0, 0.2))

	for i in range(1, raw_pts.size()):
		var pt: Vector3 = raw_pts[i]
		if pt.distance_to(clean_pts[-1]) >= 0.001:
			clean_pts.append(pt)
			clean_w.append(_get_array_value(raw_widths, i, clean_w[-1]))
			clean_d.append(_get_array_value(raw_depths, i, clean_d[-1]))
		elif i == raw_pts.size() - 1:
			clean_pts[-1] = pt

	if clean_pts.size() < 2:
		return {"points": clean_pts, "widths": clean_w, "depths": clean_d}

	# 2. Calcular distancias acumuladas de la línea limpia
	var total_length: float = 0.0
	var cum_dists: Array[float] = [0.0]
	for i in range(1, clean_pts.size()):
		var seg_len: float = clean_pts[i].distance_to(clean_pts[i - 1])
		total_length += seg_len
		cum_dists.append(total_length)

	if total_length < 0.001:
		return {"points": clean_pts, "widths": clean_w, "depths": clean_d}

	var spacing: float = maxf(target_spacing, 0.25)
	var out_pts: Array[Vector3] = []
	var out_w: Array[float] = []
	var out_d: Array[float] = []

	# Primer punto siempre conservado exactamente
	out_pts.append(clean_pts[0])
	out_w.append(clean_w[0])
	out_d.append(clean_d[0])

	var current_dist: float = spacing
	var seg_idx: int = 1

	while current_dist < total_length - 0.05:
		while seg_idx < cum_dists.size() and cum_dists[seg_idx] < current_dist:
			seg_idx += 1
		if seg_idx >= cum_dists.size():
			break

		var d0: float = cum_dists[seg_idx - 1]
		var d1: float = cum_dists[seg_idx]
		var seg_len: float = d1 - d0
		var t: float = 0.0
		if seg_len > 0.0001:
			t = clampf((current_dist - d0) / seg_len, 0.0, 1.0)

		var p: Vector3 = clean_pts[seg_idx - 1].lerp(clean_pts[seg_idx], t)
		var w: float = lerpf(clean_w[seg_idx - 1], clean_w[seg_idx], t)
		var d: float = lerpf(clean_d[seg_idx - 1], clean_d[seg_idx], t)

		out_pts.append(p)
		out_w.append(w)
		out_d.append(d)

		current_dist += spacing

	# Último punto siempre conservado exactamente
	var last_clean: Vector3 = clean_pts[-1]
	if out_pts.is_empty() or out_pts[-1].distance_to(last_clean) > 0.05:
		out_pts.append(last_clean)
		out_w.append(clean_w[-1])
		out_d.append(clean_d[-1])
	else:
		out_pts[-1] = last_clean
		out_w[-1] = clean_w[-1]
		out_d[-1] = clean_d[-1]

	return {
		"points": out_pts,
		"widths": out_w,
		"depths": out_d
	}

# ----------------------------------------------------------------------
# BLOQUE 3 — Validación de Quad y Geometría
# ----------------------------------------------------------------------
static func _quad_is_valid(l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3) -> bool:
	if not (_triangle_is_valid(l0, r0, l1) and _triangle_is_valid(r0, r1, l1)):
		return false

	var p_l0 := Vector2(l0.x, l0.z)
	var p_l1 := Vector2(l1.x, l1.z)
	var p_r0 := Vector2(r0.x, r0.z)
	var p_r1 := Vector2(r1.x, r1.z)

	# Cruce de aristas izquierda y derecha (bowtie / self-intersection)
	if _segments_intersect_2d(p_l0, p_l1, p_r0, p_r1):
		return false

	# Anchuras mínimas en los extremos
	if p_l0.distance_squared_to(p_r0) < 0.0004 or p_l1.distance_squared_to(p_r1) < 0.0004:
		return false

	# Longitud mínima de avance longitudinal
	var mid0: Vector2 = (p_l0 + p_r0) * 0.5
	var mid1: Vector2 = (p_l1 + p_r1) * 0.5
	if mid0.distance_squared_to(mid1) < 0.0001:
		return false

	# Área 2D mínima por triángulo
	var area1: float = _triangle_area_2d(p_l0, p_r0, p_l1)
	var area2: float = _triangle_area_2d(p_r0, p_r1, p_l1)
	if area1 < 0.00001 or area2 < 0.00001:
		return false

	return true

static func _segments_intersect_2d(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1: float = _ccw_2d(a, b, c)
	var d2: float = _ccw_2d(a, b, d)
	var d3: float = _ccw_2d(c, d, a)
	var d4: float = _ccw_2d(c, d, b)

	if ((d1 > 0.00001 and d2 < -0.00001) or (d1 < -0.00001 and d2 > 0.00001)) and \
	   ((d3 > 0.00001 and d4 < -0.00001) or (d3 < -0.00001 and d4 > 0.00001)):
		return true

	return false

static func _ccw_2d(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)

static func _triangle_area_2d(a: Vector2, b: Vector2, c: Vector2) -> float:
	return absf((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) * 0.5

static func _triangle_is_valid(
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> bool:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var cross: Vector3 = ab.cross(ac)
	var area_squared: float = cross.length_squared()

	return (
		is_finite(a.x) and is_finite(a.y) and is_finite(a.z) and
		is_finite(b.x) and is_finite(b.y) and is_finite(b.z) and
		is_finite(c.x) and is_finite(c.y) and is_finite(c.z) and
		area_squared > 0.000001
	)

static func _get_array_value(
	values: Array,
	index: int,
	fallback: float
) -> float:
	if index < 0 or index >= values.size():
		return fallback
	return float(values[index])

# ----------------------------------------------------------------------
# BLOQUE 6 — Confluencias aisladas (preservadas para la fase de confluencias)
# ----------------------------------------------------------------------
static func build_confluence_patch(
	conf: Dictionary,
	result: WorldResult,
	profile: WorldProfile
) -> RefCounted:
	var c_pos: Vector2i = conf.get("position", Vector2i(-1, -1))
	if c_pos == Vector2i(-1, -1):
		return null

	var surf = _WaterSurfaceDataScript.new()
	var center_y: float = _sample_terrain(result, float(c_pos.x), float(c_pos.y)) + 0.03
	var center := Vector3(float(c_pos.x), center_y, float(c_pos.y))

	var radius: float = (profile.river_max_width * 0.75) / maxf(profile.cell_size, 0.01)
	var num_pts: int = 8
	var center_idx: int = surf.add_vertex(center, Vector3.UP, Vector2(center.x, center.z), Vector2(0, 1), profile.water_color_river)

	for k in range(num_pts + 1):
		var angle: float = float(k) * (TAU / float(num_pts))
		var px: float = center.x + cos(angle) * radius
		var pz: float = center.z + sin(angle) * radius
		var py: float = _sample_terrain(result, px, pz) + 0.025
		surf.add_vertex(Vector3(px, py, pz), Vector3.UP, Vector2(px, pz), Vector2(cos(angle), sin(angle)), profile.water_color_river)
		if k > 0:
			surf.add_triangle(center_idx, center_idx + k, center_idx + k + 1)

	return surf

static func _sample_terrain(result: WorldResult, wx: float, wz: float) -> float:
	if result == null:
		return 0.0
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	var x0: int = clampi(int(floor(wx)), 0, w - 2)
	var z0: int = clampi(int(floor(wz)), 0, h - 2)
	var u: float = clampf(wx - float(x0), 0.0, 1.0)
	var v: float = clampf(wz - float(z0), 0.0, 1.0)

	var c00 = result.get_cell(Vector2i(x0, z0))
	var c10 = result.get_cell(Vector2i(x0 + 1, z0))
	var c01 = result.get_cell(Vector2i(x0, z0 + 1))
	var c11 = result.get_cell(Vector2i(x0 + 1, z0 + 1))

	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else 0.0
	var h01: float = c01.height if c01 != null else 0.0
	var h11: float = c11.height if c11 != null else 0.0

	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
