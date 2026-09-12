class_name JunctionValidator
extends RefCounted

## Validador geométrico integral y específico para superficies de confluencia (Junctions).
## Verifica los 7 pilares de sanidad geométrica y topológica:
## 1. Ausencia de cruce de bordes laterales (bowtie / self-intersection en XZ).
## 2. Ausencia de inversión de quads (orientación de normales y áreas con signo consistentes).
## 3. Continuidad entre estaciones (cota vertical delta_y <= 1.5 m y alineación direccional).
## 4. Ausencia de gaps entre ramas (convergencia exacta en la salida downstream y cierre de cuña interior).
## 5. Ausencia de anomalías de ancho (sin colapso < 0.05 m, ratio en [0.25, 4.0]).
## 6. Ausencia de anomalías de desplazamiento (progreso longitudinal positivo en [0.001, 10.0] m sin retroceso).
## 7. Continuidad junction <-> ribbon (acoplamiento exacto con márgenes de recorte < 0.05 m en upstream y downstream).

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

# ----------------------------------------------------------------------
# 1. Validación de Quad Individual
# ----------------------------------------------------------------------
static func validate_quad(l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3) -> Dictionary:
	var errors: Array[String] = []
	var has_crossing: bool = false
	var is_inverted: bool = false
	var station_discontinuity: bool = false
	var width_anomaly: bool = false
	var displacement_anomaly: bool = false

	# 1. Finitud
	if not (is_finite(l0.x) and is_finite(l0.y) and is_finite(l0.z) and
		is_finite(r0.x) and is_finite(r0.y) and is_finite(r0.z) and
		is_finite(l1.x) and is_finite(l1.y) and is_finite(l1.z) and
		is_finite(r1.x) and is_finite(r1.y) and is_finite(r1.z)):
		errors.append("Non-finite vertex coordinates in junction quad")
		return {
			"valid": false,
			"errors": errors,
			"has_crossing": false,
			"is_inverted": false,
			"station_discontinuity": false,
			"width_anomaly": false,
			"displacement_anomaly": false,
			"metrics": {}
		}

	# 2. Área 3D mínima por triángulo (no degeneración)
	var cross_a: Vector3 = (r0 - l0).cross(l1 - l0)
	var cross_b: Vector3 = (r1 - r0).cross(l1 - r0)
	var area_a: float = cross_a.length() * 0.5
	var area_b: float = cross_b.length() * 0.5

	if area_a < 0.000001 or area_b < 0.000001:
		errors.append("Degenerate triangle in junction quad (area_a: %f, area_b: %f)" % [area_a, area_b])

	# 3. Crossing de bordes (Aristas laterales cruzadas en XZ)
	var pl0 := Vector2(l0.x, l0.z)
	var pl1 := Vector2(l1.x, l1.z)
	var pr0 := Vector2(r0.x, r0.z)
	var pr1 := Vector2(r1.x, r1.z)

	if _segments_intersect_2d(pl0, pl1, pr0, pr1):
		has_crossing = true
		errors.append("Crossed lateral edges in junction quad (bowtie self-intersection)")

	# 4. Inversión de quad (áreas 2D con orientación opuesta o normales 3D plegadas)
	var signed_area_1: float = (r0.x - l0.x) * (l1.z - l0.z) - (r0.z - l0.z) * (l1.x - l0.x)
	var signed_area_2: float = (r1.x - r0.x) * (l1.z - r0.z) - (r1.z - r0.z) * (l1.x - r0.x)
	var area_product_2d: float = signed_area_1 * signed_area_2
	var normal_dot: float = cross_a.dot(cross_b)
	if normal_dot <= 0.00001 or area_product_2d <= 0.00001:
		is_inverted = true
		errors.append("Inverted quad: inconsistent signed orientation/normal (normal_dot: %f, product_2d: %f)" % [normal_dot, area_product_2d])

	# 5. Continuidad entre estaciones (salto vertical de cota de agua)
	var y0: float = (l0.y + r0.y) * 0.5
	var y1: float = (l1.y + r1.y) * 0.5
	var delta_y: float = absf(y1 - y0)
	if delta_y > 1.5:
		station_discontinuity = true
		errors.append("Station height discontinuity: delta_y %f > 1.5 m" % delta_y)

	# 6. Anomalías de ancho (colapso absoluto o ratio expansivo anómalo)
	var w0: float = pl0.distance_to(pr0)
	var w1: float = pl1.distance_to(pr1)
	var width_ratio: float = 1.0
	if w0 < 0.05 or w1 < 0.05:
		width_anomaly = true
		errors.append("Station width collapsed (< 0.05 m): w0=%f, w1=%f" % [w0, w1])
	else:
		width_ratio = w1 / w0
		if width_ratio < 0.25 or width_ratio > 4.0:
			width_anomaly = true
			errors.append("Station width ratio anomaly: %f (expected in [0.25, 4.0])" % width_ratio)

	# 7. Anomalías de desplazamiento (avance longitudinal nulo, excesivo o retrógrado)
	var mid0: Vector2 = (pl0 + pr0) * 0.5
	var mid1: Vector2 = (pl1 + pr1) * 0.5
	var step_dist: float = mid0.distance_to(mid1)
	if step_dist < 0.001 or step_dist > 10.0:
		displacement_anomaly = true
		errors.append("Longitudinal progression anomaly: step_dist %f (expected in [0.001, 10.0])" % step_dist)

	var disp: Vector2 = mid1 - mid0
	var lateral0 := Vector2(pr0.x - pl0.x, pr0.y - pl0.y)
	var fwd0 := Vector2(-lateral0.y, lateral0.x)
	if fwd0.dot(disp) <= 0.0:
		displacement_anomaly = true
		errors.append("Retrograde longitudinal progression in junction quad")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"has_crossing": has_crossing,
		"is_inverted": is_inverted,
		"station_discontinuity": station_discontinuity,
		"width_anomaly": width_anomaly,
		"displacement_anomaly": displacement_anomaly,
		"metrics": {
			"area_a": area_a,
			"area_b": area_b,
			"step_dist": step_dist,
			"w0": w0,
			"w1": w1,
			"width_ratio": width_ratio,
			"delta_y": delta_y
		}
	}

# ----------------------------------------------------------------------
# 2. Validación de Gaps entre Ramas Adyacentes
# ----------------------------------------------------------------------
static func validate_inter_branch_gaps(station_grid: Array) -> Dictionary:
	var errors: Array[String] = []
	var n_branches: int = station_grid.size()
	if n_branches < 2:
		return {"valid": true, "errors": errors, "gap_count": 0}

	var gap_count: int = 0
	var m_steps: int = station_grid[0].size() - 1

	# Verificar convergencia en la estación de salida final (m = m_steps)
	for k in range(n_branches - 1):
		var branch_curr: Array = station_grid[k]
		var branch_next: Array = station_grid[k + 1]
		var st_curr_end: Dictionary = branch_curr[m_steps]
		var st_next_end: Dictionary = branch_next[m_steps]

		var r_curr_exit: Vector3 = st_curr_end["right"]
		var l_next_exit: Vector3 = st_next_end["left"]
		var exit_gap: float = r_curr_exit.distance_to(l_next_exit)

		if exit_gap > 0.02:
			gap_count += 1
			errors.append("Inter-branch gap at downstream exit between branches %d and %d: %f m (> 0.02 m)" % [k, k + 1, exit_gap])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"gap_count": gap_count
	}

# ----------------------------------------------------------------------
# 3. Validación de Continuidad Junction <-> Ribbons
# ----------------------------------------------------------------------
static func validate_junction_ribbon_continuity(
	conf: Dictionary,
	network: Variant,
	result: RefCounted,
	profile: RefCounted,
	station_grid: Array
) -> Dictionary:
	var errors: Array[String] = []
	if network == null or station_grid.is_empty():
		return {"valid": true, "errors": errors, "continuity_errors": 0}

	var down_id: int = conf.get("downstream_river", -1)
	var up_ids: Array = conf.get("upstream_rivers", [])
	var cell_size: float = maxf(profile.cell_size, 0.01) if profile != null else 1.0

	var continuity_errors: int = 0

	# 1. Continuidad Upstream (en m = 0 para cada afluente)
	var n_branches: int = station_grid.size()
	for k in range(n_branches):
		var j_st0: Dictionary = station_grid[k][0]
		var r_id: int = j_st0.get("river_id", -1)
		var u_river = null
		if r_id != -1 and network.has_method("get_river"):
			u_river = network.get_river(r_id)
		elif k < up_ids.size() and network.has_method("get_river"):
			u_river = network.get_river(up_ids[k])

		if u_river == null:
			continue

		var u_st: Dictionary = _RiverMeshBuilderScript.get_river_boundary_station(u_river, false, cell_size, result)
		if u_st.is_empty():
			continue

		var dist_l: float = j_st0["left"].distance_to(u_st["left"])
		var dist_r: float = j_st0["right"].distance_to(u_st["right"])
		var dist_y: float = absf(j_st0["water_y"] - u_st["water_y"])

		if dist_l > 0.05 or dist_r > 0.05 or dist_y > 0.05:
			continuity_errors += 1
			errors.append("Upstream ribbon continuity mismatch at branch %d (river %d): dist_l=%f, dist_r=%f, dist_y=%f" % [k, r_id, dist_l, dist_r, dist_y])

	# 2. Continuidad Downstream (en m = m_steps)
	var down_river = network.get_river(down_id) if network.has_method("get_river") else null
	if down_river != null and n_branches > 0:
		var conf_pos_2d: Vector2i = conf.get("position", Vector2i(-1, -1))
		var conf_world_pos: Vector3 = Vector3(
			conf_pos_2d.x * cell_size + cell_size * 0.5,
			0.0,
			conf_pos_2d.y * cell_size + cell_size * 0.5
		)
		var down_st: Dictionary = _RiverMeshBuilderScript.get_river_boundary_station(down_river, true, cell_size, result, conf_world_pos)
		if not down_st.is_empty():
			var m_steps: int = station_grid[0].size() - 1
			var j_exit_l: Vector3 = station_grid[0][m_steps]["left"]
			var j_exit_r: Vector3 = station_grid[n_branches - 1][m_steps]["right"]
			var j_exit_y: float = station_grid[0][m_steps]["water_y"]

			var dist_exit_l: float = j_exit_l.distance_to(down_st["left"])
			var dist_exit_r: float = j_exit_r.distance_to(down_st["right"])
			var dist_exit_y: float = absf(j_exit_y - down_st["water_y"])

			if dist_exit_l > 0.05 or dist_exit_r > 0.05 or dist_exit_y > 0.05:
				continuity_errors += 1
				errors.append("Downstream ribbon continuity mismatch: dist_l=%f, dist_r=%f, dist_y=%f" % [dist_exit_l, dist_exit_r, dist_exit_y])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"continuity_errors": continuity_errors
	}

# ----------------------------------------------------------------------
# 4. Validación de Superficie Completa de Junction (Mesh Data)
# ----------------------------------------------------------------------
static func validate_junction_surface(
	surf: RefCounted,
	expected_branches: int,
	m_steps: int
) -> Dictionary:
	var errors: Array[String] = []

	if surf == null:
		return {"valid": false, "errors": ["Junction surface is null"]}

	var verts: Array = surf.vertices if "vertices" in surf else []
	var indices: Array = surf.indices if "indices" in surf else []

	# Con compartición exacta de vértices en costuras internas, N ramas comparten bordes adyacentes:
	# número mínimo de vértices es (expected_branches + 1) * (m_steps + 1)
	var min_verts: int = (expected_branches + 1) * (m_steps + 1)
	var min_tris: int = expected_branches * m_steps * 2

	if verts.size() < min_verts:
		errors.append("Vertex count too low: %d (expected >= %d)" % [verts.size(), min_verts])

	if (indices.size() / 3) < min_tris:
		errors.append("Triangle count too low: %d (expected >= %d)" % [indices.size() / 3, min_tris])

	# Chequeo de triángulos individuales
	var degenerate_count: int = 0
	var inverted_face_count: int = 0
	for i in range(0, indices.size(), 3):
		var i0: int = indices[i]
		var i1: int = indices[i + 1]
		var i2: int = indices[i + 2]

		if i0 == i1 or i1 == i2 or i0 == i2:
			degenerate_count += 1
			continue

		var v0: Vector3 = verts[i0]
		var v1: Vector3 = verts[i1]
		var v2: Vector3 = verts[i2]

		var cross: Vector3 = (v1 - v0).cross(v2 - v0)
		var area: float = cross.length() * 0.5
		if area < 0.000001:
			degenerate_count += 1

		# Normal Y check (la superficie de agua debe mirar hacia arriba)
		if cross.y >= 0.0:
			inverted_face_count += 1

	if degenerate_count > 0:
		errors.append("Found %d degenerate triangles in junction surface" % degenerate_count)
	if inverted_face_count > 0:
		errors.append("Found %d inverted face triangles in junction surface" % inverted_face_count)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"metrics": {
			"vertices": verts.size(),
			"triangles": indices.size() / 3,
			"degenerate_triangles": degenerate_count,
			"inverted_faces": inverted_face_count,
			"branches": expected_branches,
			"m_steps": m_steps
		}
	}

# ----------------------------------------------------------------------
# 5. Validación Integral Unificada de Junction (Todos los 7 Factores)
# ----------------------------------------------------------------------
static func validate_full_junction(
	conf: Dictionary,
	network: Variant,
	result: RefCounted,
	profile: RefCounted,
	surf: RefCounted,
	station_grid: Array = []
) -> Dictionary:
	var all_errors: Array[String] = []

	var n_up: int = conf.get("upstream_rivers", []).size()
	var m_steps: int = 3

	# Generar station_grid si no se proporcionó
	if station_grid.is_empty() and network != null and profile != null:
		station_grid = _RiverMeshBuilderScript._generate_explicit_junction_stations(conf, network, result, profile, m_steps)

	var quads_checked: int = 0
	var crossed_edges: int = 0
	var inverted_quads: int = 0
	var station_discontinuities: int = 0
	var width_anomalies: int = 0
	var displacement_anomalies: int = 0

	# 1. Validar todos los quads en station_grid
	for k in range(station_grid.size()):
		var branch: Array = station_grid[k]
		for m in range(branch.size() - 1):
			quads_checked += 1
			var st0: Dictionary = branch[m]
			var st1: Dictionary = branch[m + 1]
			var q_res: Dictionary = validate_quad(st0["left"], st0["right"], st1["left"], st1["right"])
			if not q_res["valid"]:
				all_errors.append_array(q_res["errors"])
			if q_res.get("has_crossing", false):
				crossed_edges += 1
			if q_res.get("is_inverted", false):
				inverted_quads += 1
			if q_res.get("station_discontinuity", false):
				station_discontinuities += 1
			if q_res.get("width_anomaly", false):
				width_anomalies += 1
			if q_res.get("displacement_anomaly", false):
				displacement_anomalies += 1

	# 2. Validar gaps entre ramas
	var gaps_res: Dictionary = validate_inter_branch_gaps(station_grid)
	if not gaps_res["valid"]:
		all_errors.append_array(gaps_res["errors"])
	var inter_branch_gaps: int = gaps_res.get("gap_count", 0)

	# 3. Validar continuidad junction <-> ribbon
	var cont_res: Dictionary = validate_junction_ribbon_continuity(conf, network, result, profile, station_grid)
	if not cont_res["valid"]:
		all_errors.append_array(cont_res["errors"])
	var ribbon_continuity_errors: int = cont_res.get("continuity_errors", 0)

	# 4. Validar surface mesh
	var surf_res: Dictionary = validate_junction_surface(surf, n_up, m_steps)
	if not surf_res["valid"]:
		all_errors.append_array(surf_res["errors"])
	var degenerate_triangles: int = surf_res.get("metrics", {}).get("degenerate_triangles", 0)

	return {
		"valid": all_errors.is_empty(),
		"errors": all_errors,
		"metrics": {
			"quads_checked": quads_checked,
			"triangles_checked": surf.indices.size() / 3 if (surf != null and "indices" in surf) else 0,
			"crossed_edges": crossed_edges,
			"inverted_quads": inverted_quads,
			"station_discontinuities": station_discontinuities,
			"inter_branch_gaps": inter_branch_gaps,
			"width_anomalies": width_anomalies,
			"displacement_anomalies": displacement_anomalies,
			"ribbon_continuity_errors": ribbon_continuity_errors,
			"degenerate_triangles": degenerate_triangles
		}
	}

# ----------------------------------------------------------------------
# Helper Geométrico 2D
# ----------------------------------------------------------------------
static func _segments_intersect_2d(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1: float = _ccw(a, b, c)
	var d2: float = _ccw(a, b, d)
	var d3: float = _ccw(c, d, a)
	var d4: float = _ccw(c, d, b)

	if ((d1 > 0.00001 and d2 < -0.00001) or (d1 < -0.00001 and d2 > 0.00001)) and \
	   ((d3 > 0.00001 and d4 < -0.00001) or (d3 < -0.00001 and d4 > 0.00001)):
		return true

	return false

static func _ccw(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
