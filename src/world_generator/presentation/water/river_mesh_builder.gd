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
	profile: WorldProfile,
	network: Variant = null
) -> RefCounted:
	var raw_pts: Array = []
	var raw_widths: Array = []
	var raw_depths: Array = []

	if river is River:
		raw_pts = river.points.duplicate()
		raw_widths = river.widths.duplicate()
		raw_depths = river.depths.duplicate()
	elif river is Dictionary:
		raw_pts = river.get("points", []).duplicate()
		raw_widths = river.get("widths", []).duplicate()
		raw_depths = river.get("depths", []).duplicate()
	else:
		return null

	if raw_pts.size() < 2:
		return null

	# ------------------------------------------------------------------
	# BLOQUE 2 — Ownership y recorte de ribbons
	# El ribbon cede el espacio de la zona de confluencia a la junction.
	# ------------------------------------------------------------------
	var has_downstream: bool = false
	var has_upstream: bool = false
	if river is River:
		has_downstream = (river.downstream_river != -1)
		has_upstream = not river.upstream_rivers.is_empty()
	elif river is Dictionary:
		has_downstream = (river.get("downstream_river", -1) != -1)
		has_upstream = not river.get("upstream_rivers", []).is_empty()

	if raw_pts.size() >= 3:
		var trim_len: float = 0.75
		if has_downstream:
			var p_last: Vector3 = raw_pts[-1]
			var p_prev: Vector3 = raw_pts[-2]
			var seg_d: float = p_last.distance_to(p_prev)
			if seg_d > trim_len * 1.5:
				var t_trim: float = clampf(1.0 - (trim_len / seg_d), 0.5, 0.95)
				raw_pts[-1] = p_prev.lerp(p_last, t_trim)

		if has_upstream:
			var p_first: Vector3 = raw_pts[0]
			var p_next: Vector3 = raw_pts[1]
			var seg_d: float = p_first.distance_to(p_next)
			if seg_d > trim_len * 1.5:
				var t_trim: float = clampf(trim_len / seg_d, 0.05, 0.5)
				raw_pts[0] = p_first.lerp(p_next, t_trim)

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

	# ------------------------------------------------------------------
	# TELEMETRÍA EFÍMERA DE DIAGNÓSTICO
	# ------------------------------------------------------------------
	var diagnostics := {
		"sections": pts.size(),
		"quads": maxi(pts.size() - 1, 0),
		"fallback_normal_previous": 0,
		"fallback_normal_next": 0,
		"fallback_width_85": 0,
		"fallback_width_70": 0,
		"fallback_width_55": 0,
		"fallback_width_40": 0,
		"fallback_safe": 0,
		"invalid_quads_before_fallback": 0,
		"invalid_quads_after_fallback": 0,
		"skipped_triangles": 0,
		"valid_triangles": 0,
		"min_width": INF,
		"max_width": 0.0,
		"min_segment_length": INF,
		"max_segment_length": 0.0,
		"turns_gt_30": 0,
		"turns_gt_60": 0,
		"turns_gt_90": 0
	}

	for i in range(pts.size()):
		var p: Vector3 = pts[i]

		# 2.1 Tangente y ángulos de giro
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

			# Medir ángulo de giro entre segmentos
			if prev_dir.length_squared() > 0.0001 and next_dir.length_squared() > 0.0001:
				var turn_deg := rad_to_deg(acos(clampf(prev_dir.dot(next_dir), -1.0, 1.0)))
				if turn_deg > 90.0:
					diagnostics["turns_gt_90"] += 1
				elif turn_deg > 60.0:
					diagnostics["turns_gt_60"] += 1
				elif turn_deg > 30.0:
					diagnostics["turns_gt_30"] += 1

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
		var effective_width: float = base_half_width * 2.0
		diagnostics["min_width"] = minf(float(diagnostics["min_width"]), effective_width)
		diagnostics["max_width"] = maxf(float(diagnostics["max_width"]), effective_width)

		if i > 0:
			var seg_len: float = pts[i].distance_to(pts[i - 1])
			diagnostics["min_segment_length"] = minf(float(diagnostics["min_segment_length"]), seg_len)
			diagnostics["max_segment_length"] = maxf(float(diagnostics["max_segment_length"]), seg_len)

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
				diagnostics["invalid_quads_before_fallback"] += 1

				# Fallback A: Normal del segmento anterior
				if prev_norm != Vector3.ZERO:
					var cand_l_a := p + prev_norm * base_half_width
					var cand_r_a := p - prev_norm * base_half_width
					if _quad_is_valid(prev_l, prev_r, cand_l_a, cand_r_a):
						chosen_normal = prev_norm
						chosen_left = cand_l_a
						chosen_right = cand_r_a
						quad_ok = true
						diagnostics["fallback_normal_previous"] += 1

				# Fallback B: Normal del segmento siguiente
				if not quad_ok and next_norm != Vector3.ZERO:
					var cand_l_b := p + next_norm * base_half_width
					var cand_r_b := p - next_norm * base_half_width
					if _quad_is_valid(prev_l, prev_r, cand_l_b, cand_r_b):
						chosen_normal = next_norm
						chosen_left = cand_l_b
						chosen_right = cand_r_b
						quad_ok = true
						diagnostics["fallback_normal_next"] += 1

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
								if is_equal_approx(factor, 0.85): diagnostics["fallback_width_85"] += 1
								elif is_equal_approx(factor, 0.70): diagnostics["fallback_width_70"] += 1
								elif is_equal_approx(factor, 0.55): diagnostics["fallback_width_55"] += 1
								elif is_equal_approx(factor, 0.40): diagnostics["fallback_width_40"] += 1
								break
						if quad_ok:
							break

				# Si todo falla, forzar normal previa y ancho al 40% para mantener coherencia
				if not quad_ok:
					diagnostics["fallback_safe"] += 1
					diagnostics["invalid_quads_after_fallback"] += 1
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
	# dos triángulos por segmento longitudinal con conteo diagnóstico.
	# ------------------------------------------------------------------
	for i in range(pts.size() - 1):
		var l0: int = left_indices[i]
		var r0: int = right_indices[i]
		var l1: int = left_indices[i + 1]
		var r1: int = right_indices[i + 1]

		var tri_a_valid: bool = _triangle_is_valid(surf.vertices[l0], surf.vertices[r0], surf.vertices[l1])
		var tri_b_valid: bool = _triangle_is_valid(surf.vertices[r0], surf.vertices[r1], surf.vertices[l1])

		if tri_a_valid:
			surf.add_triangle(l0, r0, l1)
			diagnostics["valid_triangles"] += 1
		else:
			diagnostics["skipped_triangles"] += 1

		if tri_b_valid:
			surf.add_triangle(r0, r1, l1)
			diagnostics["valid_triangles"] += 1
		else:
			diagnostics["skipped_triangles"] += 1

	var fallback_total: int = (
		diagnostics["fallback_normal_previous"]
		+ diagnostics["fallback_normal_next"]
		+ diagnostics["fallback_width_85"]
		+ diagnostics["fallback_width_70"]
		+ diagnostics["fallback_width_55"]
		+ diagnostics["fallback_width_40"]
		+ diagnostics["fallback_safe"]
	)
	var fallback_ratio: float = 0.0
	if diagnostics["sections"] > 1:
		fallback_ratio = float(fallback_total) / float(diagnostics["sections"] - 1)

	print(
		"[RiverMeshDiagnostics] ",
		"sections=", diagnostics["sections"],
		" quads=", diagnostics["quads"],
		" invalid_before=", diagnostics["invalid_quads_before_fallback"],
		" invalid_after=", diagnostics["invalid_quads_after_fallback"],
		" prev_normal=", diagnostics["fallback_normal_previous"],
		" next_normal=", diagnostics["fallback_normal_next"],
		" width85=", diagnostics["fallback_width_85"],
		" width70=", diagnostics["fallback_width_70"],
		" width55=", diagnostics["fallback_width_55"],
		" width40=", diagnostics["fallback_width_40"],
		" safe=", diagnostics["fallback_safe"],
		" skipped_triangles=", diagnostics["skipped_triangles"],
		" valid_triangles=", diagnostics["valid_triangles"],
		" fallback_ratio=", "%.4f" % fallback_ratio,
		" turns>30=", diagnostics["turns_gt_30"],
		" turns>60=", diagnostics["turns_gt_60"],
		" turns>90=", diagnostics["turns_gt_90"],
		" min_width=", "%.2f" % diagnostics["min_width"] if is_finite(diagnostics["min_width"]) else "0.0",
		" max_width=", "%.2f" % diagnostics["max_width"],
		" min_segment=", "%.2f" % diagnostics["min_segment_length"] if is_finite(diagnostics["min_segment_length"]) else "0.0",
		" max_segment=", "%.2f" % diagnostics["max_segment_length"]
	)

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
# BLOQUE C — Confluencias continuas con estaciones longitudinales (C1 a C8)
# ----------------------------------------------------------------------
static func build_confluence_surface(
	conf: Dictionary,
	result: WorldResult,
	profile: WorldProfile,
	network: Variant = null,
	longitudinal_steps: int = 3
) -> RefCounted:
	if network == null and result != null and result.hydrology != null:
		network = result.hydrology.get_river_network()

	var down_id: int = conf.get("downstream_river", -1)
	var up_ids: Array = conf.get("upstream_rivers", [])

	if down_id == -1 or up_ids.is_empty():
		return null

	var down_river = network.get_river(down_id) if network != null else null
	if down_river == null:
		return null

	var cell_size: float = maxf(profile.cell_size, 0.01)
	var down_st: Dictionary = _get_river_boundary_station(down_river, true, cell_size, result)
	if down_st.is_empty():
		return null

	var up_stations: Array[Dictionary] = []
	for uid in up_ids:
		var u_river = network.get_river(uid) if network != null else null
		if u_river != null:
			var u_st = _get_river_boundary_station(u_river, false, cell_size, result)
			if not u_st.is_empty():
				up_stations.append(u_st)

	if up_stations.is_empty():
		return null

	# Ordenar los afluentes de izquierda a derecha respecto a downstream
	var down_angle: float = atan2(down_st.dir.x, down_st.dir.z)
	up_stations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var dir_a: Vector3 = -a.dir
		var dir_b: Vector3 = -b.dir
		var angle_a: float = wrapf(atan2(dir_a.x, dir_a.z) - down_angle, -PI, PI)
		var angle_b: float = wrapf(atan2(dir_b.x, dir_b.z) - down_angle, -PI, PI)
		return angle_a < angle_b
	)

	var surf = _WaterSurfaceDataScript.new()
	var n_branches: int = up_stations.size()
	var m_steps: int = maxi(longitudinal_steps, 2) # M estaciones longitudinales

	# ------------------------------------------------------------------
	# Matriz de estaciones longitudinales: grid_left[branch][step], grid_right[branch][step]
	# BLOQUE 1 — Ancho como magnitud explícita de verdad
	# ------------------------------------------------------------------
	var grid_left: Array = []   # Array[Array[int]]
	var grid_right: Array = []  # Array[Array[int]]
	grid_left.resize(n_branches)
	grid_right.resize(n_branches)

	for k in range(n_branches):
		grid_left[k] = []
		grid_right[k] = []
		grid_left[k].resize(m_steps + 1)
		grid_right[k].resize(m_steps + 1)

		var u: Dictionary = up_stations[k]
		var t_k_left: float = float(k) / float(n_branches)
		var t_k_right: float = float(k + 1) / float(n_branches)

		var width_start: float = u.width
		var width_end: float = down_st.width / float(n_branches)

		var target_down_l: Vector3 = down_st.left.lerp(down_st.right, t_k_left)
		var target_down_r: Vector3 = down_st.left.lerp(down_st.right, t_k_right)
		var target_center: Vector3 = (target_down_l + target_down_r) * 0.5
		var target_dir: Vector3 = down_st.dir

		for m in range(m_steps + 1):
			var tm: float = float(m) / float(m_steps)

			# 1.1 y 1.2: Ancho interpolado explícito
			var width: float = lerpf(width_start, width_end, tm)
			var half_w: float = width * 0.5

			# Centro y dirección interpolados
			var center: Vector3 = u.center.lerp(target_center, tm)
			var dir_blend: Vector3 = u.dir.lerp(target_dir, tm)
			if dir_blend.length_squared() < 0.0001:
				dir_blend = target_dir
			dir_blend.y = 0.0
			dir_blend = dir_blend.normalized()
			var norm: Vector3 = Vector3(-dir_blend.z, 0.0, dir_blend.x).normalized()

			# 1.3: Derivar left/right estrictamente de center +- norm * half_w
			var p_l: Vector3
			var p_r: Vector3

			if m == 0:
				p_l = u.left
				p_r = u.right
			elif m == m_steps:
				p_l = target_down_l
				p_r = target_down_r
			else:
				p_l = center + norm * half_w
				p_r = center - norm * half_w

			# Cota de agua interpolada y clampada al terreno
			var bed_l: float = _sample_terrain(result, p_l.x, p_l.z)
			var bed_r: float = _sample_terrain(result, p_r.x, p_r.z)
			var bank_l: float = _sample_terrain(result, p_l.x + norm.x * 0.5, p_l.z + norm.z * 0.5)
			var bank_r: float = _sample_terrain(result, p_r.x - norm.x * 0.5, p_r.z - norm.z * 0.5)

			var target_y: float = lerpf(u.water_y, down_st.water_y, tm)
			p_l.y = clampf(target_y, bed_l + 0.015, bank_l + 0.02)
			p_r.y = clampf(target_y, bed_r + 0.015, bank_r + 0.02)

			var flow_vec := Vector2(dir_blend.x, dir_blend.z)
			var uv_l := Vector2(0.0, tm)
			var uv_r := Vector2(1.0, tm)

			var idx_l: int = surf.add_vertex(p_l, Vector3.UP, uv_l, flow_vec, profile.water_color_river)
			var idx_r: int = surf.add_vertex(p_r, Vector3.UP, uv_r, flow_vec, profile.water_color_river)

			grid_left[k][m] = idx_l
			grid_right[k][m] = idx_r

	# ------------------------------------------------------------------
	# Triangulación Longitudinal por Rama (N ramas x M pasos)
	# ------------------------------------------------------------------
	for k in range(n_branches):
		for m in range(m_steps):
			var l0: int = grid_left[k][m]
			var r0: int = grid_right[k][m]
			var l1: int = grid_left[k][m + 1]
			var r1: int = grid_right[k][m + 1]

			if _triangle_is_valid(surf.vertices[l0], surf.vertices[r0], surf.vertices[l1]):
				surf.add_triangle(l0, r0, l1)
			if _triangle_is_valid(surf.vertices[r0], surf.vertices[r1], surf.vertices[l1]):
				surf.add_triangle(r0, r1, l1)

	# ------------------------------------------------------------------
	# Cuñas Interiores entre Afluentes Adyacentes (mismo nivel longitudinal)
	# ------------------------------------------------------------------
	for k in range(n_branches - 1):
		for m in range(m_steps):
			var r_curr_0: int = grid_right[k][m]
			var l_next_0: int = grid_left[k + 1][m]
			var r_curr_1: int = grid_right[k][m + 1]
			var l_next_1: int = grid_left[k + 1][m + 1]

			# Si en el paso m+1 los puntos coinciden o casi coinciden, usar 1 triángulo
			var dist_1: float = surf.vertices[r_curr_1].distance_to(surf.vertices[l_next_1])
			if dist_1 < 0.05:
				if _triangle_is_valid(surf.vertices[r_curr_0], surf.vertices[l_next_0], surf.vertices[r_curr_1]):
					surf.add_triangle(r_curr_0, l_next_0, r_curr_1)
			else:
				# Quad completo en la horquilla de convergencia
				if _triangle_is_valid(surf.vertices[r_curr_0], surf.vertices[l_next_0], surf.vertices[r_curr_1]):
					surf.add_triangle(r_curr_0, l_next_0, r_curr_1)
				if _triangle_is_valid(surf.vertices[l_next_0], surf.vertices[l_next_1], surf.vertices[r_curr_1]):
					surf.add_triangle(l_next_0, l_next_1, r_curr_1)

	return surf

static func build_confluence_patch(
	conf: Dictionary,
	result: WorldResult,
	profile: WorldProfile
) -> RefCounted:
	return build_confluence_surface(conf, result, profile, null, 3)

static func _generate_explicit_junction_stations(
	conf: Dictionary,
	network: Variant,
	result: WorldResult,
	profile: WorldProfile,
	longitudinal_steps: int = 3
) -> Array:
	var down_id: int = conf.get("downstream_river", -1)
	var up_ids: Array = conf.get("upstream_rivers", [])

	if down_id == -1 or up_ids.is_empty():
		return []

	var down_river = network.get_river(down_id) if network != null else null
	if down_river == null:
		return []

	var cell_size: float = maxf(profile.cell_size, 0.01)
	var down_st: Dictionary = _get_river_boundary_station(down_river, true, cell_size, result)
	if down_st.is_empty():
		return []

	var up_stations: Array[Dictionary] = []
	for uid in up_ids:
		var u_river = network.get_river(uid) if network != null else null
		if u_river != null:
			var u_st = _get_river_boundary_station(u_river, false, cell_size, result)
			if not u_st.is_empty():
				up_stations.append(u_st)

	if up_stations.is_empty():
		return []

	var down_angle: float = atan2(down_st.dir.x, down_st.dir.z)
	up_stations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var dir_a: Vector3 = -a.dir
		var dir_b: Vector3 = -b.dir
		var angle_a: float = wrapf(atan2(dir_a.x, dir_a.z) - down_angle, -PI, PI)
		var angle_b: float = wrapf(atan2(dir_b.x, dir_b.z) - down_angle, -PI, PI)
		return angle_a < angle_b
	)

	var n_branches: int = up_stations.size()
	var m_steps: int = maxi(longitudinal_steps, 2)
	var grid: Array = []
	grid.resize(n_branches)

	for k in range(n_branches):
		grid[k] = []
		grid[k].resize(m_steps + 1)
		var u: Dictionary = up_stations[k]
		var t_k_left: float = float(k) / float(n_branches)
		var t_k_right: float = float(k + 1) / float(n_branches)

		var width_start: float = u.width
		var width_end: float = down_st.width / float(n_branches)

		var target_down_l: Vector3 = down_st.left.lerp(down_st.right, t_k_left)
		var target_down_r: Vector3 = down_st.left.lerp(down_st.right, t_k_right)
		var target_center: Vector3 = (target_down_l + target_down_r) * 0.5
		var target_dir: Vector3 = down_st.dir

		for m in range(m_steps + 1):
			var tm: float = float(m) / float(m_steps)
			var width: float = lerpf(width_start, width_end, tm)
			var half_w: float = width * 0.5

			var center: Vector3 = u.center.lerp(target_center, tm)
			var dir_blend: Vector3 = u.dir.lerp(target_dir, tm)
			if dir_blend.length_squared() < 0.0001:
				dir_blend = target_dir
			dir_blend.y = 0.0
			dir_blend = dir_blend.normalized()
			var norm: Vector3 = Vector3(-dir_blend.z, 0.0, dir_blend.x).normalized()

			var p_l: Vector3
			var p_r: Vector3
			if m == 0:
				p_l = u.left
				p_r = u.right
			elif m == m_steps:
				p_l = target_down_l
				p_r = target_down_r
			else:
				p_l = center + norm * half_w
				p_r = center - norm * half_w

			var target_y: float = lerpf(u.water_y, down_st.water_y, tm)
			grid[k][m] = {
				"center": center,
				"dir": dir_blend,
				"normal": norm,
				"width": width,
				"half_width": half_w,
				"left": p_l,
				"right": p_r,
				"water_y": target_y
			}

	return grid

static func _extract_confluence_boundaries(
	conf: Dictionary,
	network: Variant,
	result: WorldResult,
	profile: WorldProfile
) -> Dictionary:
	var down_id: int = conf.get("downstream_river", -1)
	var up_ids: Array = conf.get("upstream_rivers", [])

	if down_id == -1 or up_ids.is_empty():
		return {}

	var down_river = network.get_river(down_id) if network != null else null
	if down_river == null:
		return {}

	var cell_size: float = maxf(profile.cell_size, 0.01)
	var down_st: Dictionary = _get_river_boundary_station(down_river, true, cell_size, result)
	if down_st.is_empty():
		return {}

	var up_stations: Array[Dictionary] = []
	var max_w: float = down_st.width
	for uid in up_ids:
		var u_river = network.get_river(uid) if network != null else null
		if u_river != null:
			var u_st = _get_river_boundary_station(u_river, false, cell_size, result)
			if not u_st.is_empty():
				up_stations.append(u_st)
				max_w = maxf(max_w, u_st.width)

	return {
		"upstreams": up_stations,
		"downstream": down_st,
		"transition_length": max_w * 1.25
	}

static func _get_river_boundary_station(
	river: Variant,
	is_start: bool,
	cell_size: float,
	result: WorldResult
) -> Dictionary:
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

	if raw_pts.size() < 2:
		return {}

	var p: Vector3
	var dir: Vector3
	var w: float
	var d: float

	var has_upstream: bool = false
	var has_downstream: bool = false
	if river is River:
		has_upstream = not river.upstream_rivers.is_empty()
		has_downstream = (river.downstream_river != -1)
	elif river is Dictionary:
		has_upstream = not river.get("upstream_rivers", []).is_empty()
		has_downstream = (river.get("downstream_river", -1) != -1)

	if is_start:
		p = raw_pts[0]
		dir = (raw_pts[1] - raw_pts[0]).normalized()
		if has_upstream and raw_pts.size() >= 3:
			var trim_len: float = 0.75
			var p_next: Vector3 = raw_pts[1]
			var seg_d: float = p.distance_to(p_next)
			if seg_d > trim_len * 1.5:
				var t_trim: float = clampf(trim_len / seg_d, 0.05, 0.5)
				p = p.lerp(p_next, t_trim)
		w = _get_array_value(raw_widths, 0, 1.0)
		d = _get_array_value(raw_depths, 0, 0.2)
	else:
		p = raw_pts[-1]
		dir = (raw_pts[-1] - raw_pts[-2]).normalized()
		if has_downstream and raw_pts.size() >= 3:
			var trim_len: float = 0.75
			var p_prev: Vector3 = raw_pts[-2]
			var seg_d: float = p.distance_to(p_prev)
			if seg_d > trim_len * 1.5:
				var t_trim: float = clampf(1.0 - (trim_len / seg_d), 0.5, 0.95)
				p = p_prev.lerp(p, t_trim)
		var last_idx: int = raw_pts.size() - 1
		w = _get_array_value(raw_widths, last_idx, 1.0)
		d = _get_array_value(raw_depths, last_idx, 0.2)

	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()

	var normal := Vector3(-dir.z, 0.0, dir.x).normalized()
	var half_w: float = maxf(w / cell_size, 0.20) * 0.5

	var left := p + normal * half_w
	var right := p - normal * half_w

	var bed_l: float = _sample_terrain(result, left.x, left.z)
	var bed_r: float = _sample_terrain(result, right.x, right.z)
	var bank_l: float = _sample_terrain(result, left.x + normal.x * 0.5, left.z + normal.z * 0.5)
	var bank_r: float = _sample_terrain(result, right.x - normal.x * 0.5, right.z - normal.z * 0.5)

	left.y = clampf(bed_l + maxf(d, 0.05), bed_l + 0.015, bank_l + 0.02)
	right.y = clampf(bed_r + maxf(d, 0.05), bed_r + 0.015, bank_r + 0.02)
	var water_y: float = (left.y + right.y) * 0.5

	return {
		"center": p,
		"dir": dir,
		"normal": normal,
		"half_width": half_w,
		"width": half_w * 2.0,
		"left": left,
		"right": right,
		"depth": d,
		"water_y": water_y
	}

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
