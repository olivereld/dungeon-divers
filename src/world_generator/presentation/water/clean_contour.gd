class_name CleanContour
extends RefCounted

## Contorno geométrico limpio y simplificado para cuerpos y canales de agua.
## Representa un polígono cerrado de frontera (shoreline) libre de ruido de discretización
## donde first != last (anillo de vértices puros sin duplicado terminal).

const DEFAULT_EPSILON: float = 0.05                 # Umbral mínimo de longitud de arista (metros)
const DEFAULT_ANGULAR_TOLERANCE_DEG: float = 2.5    # Tolerancia angular para colinealidad (grados)
const DEFAULT_MAX_GEOMETRIC_ERROR: float = 0.08     # Error geométrico máximo permitido en RDP (metros)

var points: PackedVector2Array = PackedVector2Array()
var component_id: int = 0
var is_hole: bool = false
var area: float = 0.0
var bounds: Rect2 = Rect2()

func _init(p_points: PackedVector2Array = PackedVector2Array(), p_component_id: int = 0, p_is_hole: bool = false) -> void:
	points = p_points
	component_id = p_component_id
	is_hole = p_is_hole
	_compute_metrics()

func _compute_metrics() -> void:
	var n: int = points.size()
	if n < 3:
		area = 0.0
		bounds = Rect2()
		return

	# Bounding box
	var min_pt := points[0]
	var max_pt := points[0]
	for p in points:
		min_pt.x = minf(min_pt.x, p.x)
		min_pt.y = minf(min_pt.y, p.y)
		max_pt.x = maxf(max_pt.x, p.x)
		max_pt.y = maxf(max_pt.y, p.y)
	bounds = Rect2(min_pt, max_pt - min_pt)

	# Área con signo (Fórmula Shoelace cíclica con first != last)
	var signed_area: float = 0.0
	for i in range(n):
		var next_idx: int = (i + 1) % n
		signed_area += points[i].x * points[next_idx].y - points[next_idx].x * points[i].y
	area = signed_area * 0.5

## Valida las restricciones estrictas del contorno limpio
func is_valid(epsilon: float = DEFAULT_EPSILON) -> bool:
	var n: int = points.size()
	if n < 3:
		return false

	# first != last (anillo limpio)
	if points[0].distance_squared_to(points[n - 1]) < 0.000001:
		return false

	# área > epsilon (área no nula)
	if absf(area) <= epsilon * epsilon:
		return false

	# Sin segmentos degenerados
	for i in range(n):
		var p_curr: Vector2 = points[i]
		var p_next: Vector2 = points[(i + 1) % n]
		if p_curr.distance_to(p_next) < 0.00001:
			return false

	return true

## Pipeline de limpieza ordenado de contornos geométricos
## Pasos estrictos:
## 1. Quitar puntos duplicados.
## 2. Quitar aristas longitud cero.
## 3. Quitar aristas diminutas (< epsilon).
## 4. Quitar puntos casi colineales (< angular_tolerance).
## 5. Simplificar por error geométrico máximo (RDP con max_error).
static func clean_contours(
	raw_contours: Array,
	epsilon: float = DEFAULT_EPSILON,
	angular_tol_deg: float = DEFAULT_ANGULAR_TOLERANCE_DEG,
	max_geometric_error: float = DEFAULT_MAX_GEOMETRIC_ERROR
) -> Array:
	var result: Array = []
	for raw in raw_contours:
		var cleaned: CleanContour = clean_single_contour(raw, epsilon, angular_tol_deg, max_geometric_error)
		if cleaned != null and cleaned.is_valid(epsilon):
			result.append(cleaned)
	return result

static func clean_single_contour(
	raw: Variant,
	epsilon: float = DEFAULT_EPSILON,
	angular_tol_deg: float = DEFAULT_ANGULAR_TOLERANCE_DEG,
	max_geometric_error: float = DEFAULT_MAX_GEOMETRIC_ERROR
) -> CleanContour:
	var raw_pts: PackedVector2Array = PackedVector2Array()
	var comp_id: int = 0
	var is_hole_flag: bool = false

	if raw is Object and "points" in raw:
		raw_pts = raw.points
		if "component_id" in raw: comp_id = raw.component_id
		if "is_hole" in raw: is_hole_flag = raw.is_hole
	elif raw is PackedVector2Array:
		raw_pts = raw
	elif raw is Array:
		for p in raw:
			if p is Vector2: raw_pts.append(p)
			elif p is Vector3: raw_pts.append(Vector2(p.x, p.z))

	if raw_pts.size() < 3:
		return null

	# Asegurar first != last para procesar anillo cíclico
	var pts: PackedVector2Array = raw_pts.duplicate()
	if pts.size() > 1 and pts[0].distance_squared_to(pts[-1]) < 0.000001:
		pts.remove_at(pts.size() - 1)

	if pts.size() < 3:
		return null

	# --------------------------------------------------------------------------
	# PASO 1: Quitar puntos duplicados
	# --------------------------------------------------------------------------
	var step1: PackedVector2Array = PackedVector2Array()
	for p in pts:
		if step1.is_empty() or p.distance_squared_to(step1[-1]) >= 0.000001:
			step1.append(p)
	if step1.size() > 1 and step1[0].distance_squared_to(step1[-1]) < 0.000001:
		step1.remove_at(step1.size() - 1)

	if step1.size() < 3:
		return null

	# --------------------------------------------------------------------------
	# PASO 2: Quitar aristas longitud cero
	# --------------------------------------------------------------------------
	var step2: PackedVector2Array = PackedVector2Array()
	var n1: int = step1.size()
	for i in range(n1):
		var p_curr: Vector2 = step1[i]
		var p_next: Vector2 = step1[(i + 1) % n1]
		if p_curr.distance_squared_to(p_next) > 0.000001:
			step2.append(p_curr)

	if step2.size() < 3:
		return null

	# --------------------------------------------------------------------------
	# PASO 3: Quitar aristas diminutas (< epsilon), preservando cambios importantes
	# --------------------------------------------------------------------------
	var step3: PackedVector2Array = _remove_tiny_edges(step2, epsilon)
	if step3.size() < 3:
		return null

	# --------------------------------------------------------------------------
	# PASO 4: Quitar puntos casi colineales (tolerancia angular)
	# --------------------------------------------------------------------------
	var step4: PackedVector2Array = _remove_collinear_points(step3, angular_tol_deg)
	if step4.size() < 3:
		return null

	# --------------------------------------------------------------------------
	# PASO 5: Simplificar por error geométrico máximo (RDP)
	# --------------------------------------------------------------------------
	var step5: PackedVector2Array = _simplify_by_max_error(step4, max_geometric_error)
	if step5.size() < 3:
		return null

	# Regla: first != last
	if step5.size() > 1 and step5[0].distance_squared_to(step5[-1]) < 0.000001:
		step5.remove_at(step5.size() - 1)

	if step5.size() < 3:
		return null

	# Regla: Winding consistente (CCW para exterior > 0, CW para huecos < 0)
	var final_pts: PackedVector2Array = _enforce_consistent_winding(step5, is_hole_flag)

	return CleanContour.new(final_pts, comp_id, is_hole_flag)

## Paso 3: Eliminar aristas diminutas sin eliminar cambios bruscos ni confluencias
static func _remove_tiny_edges(pts: PackedVector2Array, eps: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n <= 3:
		return pts

	var result: PackedVector2Array = PackedVector2Array()
	var eps_sq: float = eps * eps

	var i: int = 0
	while i < n:
		var p_curr: Vector2 = pts[i]
		var next_idx: int = (i + 1) % n
		var p_next: Vector2 = pts[next_idx]

		if p_curr.distance_squared_to(p_next) < eps_sq and (n - result.size()) > 3:
			# Comprobar si es un vértice de cambio de dirección importante
			var prev_idx: int = (i - 1 + n) % n
			var p_prev: Vector2 = pts[prev_idx]
			var after_idx: int = (i + 2) % n
			var p_after: Vector2 = pts[after_idx]

			var v_in: Vector2 = (p_curr - p_prev).normalized()
			var v_out: Vector2 = (p_after - p_next).normalized()
			var dot: float = clampf(v_in.dot(v_out), -1.0, 1.0)

			# Si el cambio angular es mayor a 60° (dot < 0.5), es un cambio importante: fusionar al punto medio
			if dot < 0.5:
				result.append((p_curr + p_next) * 0.5)
			else:
				result.append(p_curr)
			i += 2  # Salta p_next
		else:
			result.append(p_curr)
			i += 1

	if result.size() > 1 and result[0].distance_squared_to(result[-1]) < eps_sq and result.size() > 3:
		result.remove_at(result.size() - 1)

	return result if result.size() >= 3 else pts

## Paso 4: Eliminar puntos casi colineales
static func _remove_collinear_points(pts: PackedVector2Array, ang_deg: float) -> PackedVector2Array:
	var current: PackedVector2Array = pts.duplicate()
	var min_dot: float = cos(deg_to_rad(ang_deg))
	var changed: bool = true
	var max_iterations: int = 4

	while changed and max_iterations > 0:
		changed = false
		max_iterations -= 1
		var n: int = current.size()
		if n <= 3:
			break

		var filtered: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var p_prev: Vector2 = current[(i - 1 + n) % n]
			var p_curr: Vector2 = current[i]
			var p_next: Vector2 = current[(i + 1) % n]

			var d1: Vector2 = p_curr - p_prev
			var d2: Vector2 = p_next - p_curr
			var l1: float = d1.length()
			var l2: float = d2.length()

			if l1 > 0.0001 and l2 > 0.0001:
				var v1: Vector2 = d1 / l1
				var v2: Vector2 = d2 / l2
				var dot: float = clampf(v1.dot(v2), -1.0, 1.0)

				# Distancia perpendicular a la cuerda
				var chord: Vector2 = p_next - p_prev
				var chord_len: float = chord.length()
				var perp: float = absf(chord.x * (p_prev.y - p_curr.y) - chord.y * (p_prev.x - p_curr.x)) / maxf(chord_len, 0.0001)

				if dot >= min_dot and perp < 0.02 and (n - (n - filtered.size())) >= 3:
					changed = true
					continue  # Quitar p_curr

			filtered.append(p_curr)

		current = filtered

	return current

## Paso 5: Simplificar polígono cerrado por error geométrico máximo (Ramer-Douglas-Peucker)
static func _simplify_by_max_error(pts: PackedVector2Array, max_error: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n <= 3:
		return pts

	# Encontrar los dos vértices con mayor distancia euclidiana para dividir el lazo
	var max_dist_sq: float = -1.0
	var idx_a: int = 0
	var idx_b: int = n / 2

	for i in range(n):
		for j in range(i + 1, n):
			var d_sq: float = pts[i].distance_squared_to(pts[j])
			if d_sq > max_dist_sq:
				max_dist_sq = d_sq
				idx_a = i
				idx_b = j

	if idx_a > idx_b:
		var tmp := idx_a
		idx_a = idx_b
		idx_b = tmp

	# Cadena 1: idx_a -> idx_b
	var chain1: PackedVector2Array = PackedVector2Array()
	for i in range(idx_a, idx_b + 1):
		chain1.append(pts[i])

	# Cadena 2: idx_b -> ... -> idx_a
	var chain2: PackedVector2Array = PackedVector2Array()
	var curr: int = idx_b
	while true:
		chain2.append(pts[curr])
		if curr == idx_a:
			break
		curr = (curr + 1) % n

	var simp1: PackedVector2Array = _rdp_recursive(chain1, max_error)
	var simp2: PackedVector2Array = _rdp_recursive(chain2, max_error)

	# Unir cadenas sin duplicar extremos compartidos
	var combined: PackedVector2Array = PackedVector2Array()
	for i in range(simp1.size() - 1):
		combined.append(simp1[i])
	for i in range(simp2.size() - 1):
		combined.append(simp2[i])

	return combined if combined.size() >= 3 else pts

static func _rdp_recursive(points_chain: PackedVector2Array, max_err: float) -> PackedVector2Array:
	var n: int = points_chain.size()
	if n <= 2:
		return points_chain

	var p_start: Vector2 = points_chain[0]
	var p_end: Vector2 = points_chain[n - 1]

	var max_dist: float = 0.0
	var split_idx: int = -1

	var line_vec: Vector2 = p_end - p_start
	var line_len: float = line_vec.length()

	for i in range(1, n - 1):
		var p: Vector2 = points_chain[i]
		var dist: float = 0.0
		if line_len > 0.0001:
			dist = absf(line_vec.x * (p_start.y - p.y) - line_vec.y * (p_start.x - p.x)) / line_len
		else:
			dist = p.distance_to(p_start)

		if dist > max_dist:
			max_dist = dist
			split_idx = i

	if max_dist > max_err and split_idx != -1:
		var left_chain: PackedVector2Array = points_chain.slice(0, split_idx + 1)
		var right_chain: PackedVector2Array = points_chain.slice(split_idx, n)

		var res_left: PackedVector2Array = _rdp_recursive(left_chain, max_err)
		var res_right: PackedVector2Array = _rdp_recursive(right_chain, max_err)

		var merged: PackedVector2Array = PackedVector2Array()
		for i in range(res_left.size() - 1):
			merged.append(res_left[i])
		merged.append_array(res_right)
		return merged
	else:
		return PackedVector2Array([p_start, p_end])

## Regla: Garantizar winding consistente (CCW > 0 para exterior, CW < 0 para islas)
static func _enforce_consistent_winding(pts: PackedVector2Array, hole: bool) -> PackedVector2Array:
	var n: int = pts.size()
	var signed_area: float = 0.0
	for i in range(n):
		var next_idx: int = (i + 1) % n
		signed_area += pts[i].x * pts[next_idx].y - pts[next_idx].x * pts[i].y

	var is_ccw: bool = (signed_area > 0.0)
	var expected_ccw: bool = not hole

	if is_ccw != expected_ccw:
		var reversed: PackedVector2Array = PackedVector2Array()
		for i in range(n - 1, -1, -1):
			reversed.append(pts[i])
		return reversed

	return pts

func to_dict() -> Dictionary:
	return {
		"component_id": component_id,
		"point_count": points.size(),
		"is_hole": is_hole,
		"area": area,
		"bounds": bounds,
		"points": points
	}

func _to_string() -> String:
	return "CleanContour(comp=%d, pts=%d, hole=%s, area=%.2f)" % [
		component_id, points.size(), str(is_hole), area
	]
