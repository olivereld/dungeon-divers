class_name WaterPolygon
extends RefCounted

## Estructura topológica y geométrica de un cuerpo de agua 2D delimitado.
## Contiene un contorno exterior (anillo CCW) y cero o más agujeros/islas interiores (anillos CW).
## Confluencias conectadas pertenecen al mismo polígono como una única región continua.

var exterior: PackedVector2Array = PackedVector2Array()
var agujeros: Array[PackedVector2Array] = []
var component_id: int = 0
var area: float = 0.0
var bounds: Rect2 = Rect2()

## Alias para compatibilidad de nomenclatura
var holes: Array[PackedVector2Array]:
	get:
		return agujeros
	set(val):
		agujeros = val

func _init(
	p_exterior: PackedVector2Array = PackedVector2Array(),
	p_agujeros: Array[PackedVector2Array] = [],
	p_component_id: int = 0
) -> void:
	exterior = p_exterior
	agujeros = p_agujeros
	component_id = p_component_id
	_recompute()

## Agrega un agujero/isla interior y actualiza métricas
func add_hole(hole_pts: PackedVector2Array) -> void:
	if hole_pts.size() >= 3:
		# Asegurar winding CW para agujeros
		var cw_hole := _enforce_winding(hole_pts, true)
		agujeros.append(cw_hole)
		_recompute()

func has_holes() -> bool:
	return not agujeros.is_empty()

## Comprueba si el punto (x, y) está contenido en el agua:
## dentro del contorno exterior Y fuera de todos los agujeros (islas)
func contains_point(p: Vector2) -> bool:
	if not bounds.has_point(p):
		return false
	if not Geometry2D.is_point_in_polygon(p, exterior):
		return false
	for h in agujeros:
		if Geometry2D.is_point_in_polygon(p, h):
			return false
	return true

## Valida las restricciones del polígono
func is_valid() -> bool:
	if exterior.size() < 3:
		return false
	if area <= 0.0001:
		return false
	# first != last en el anillo
	if exterior[0].distance_squared_to(exterior[exterior.size() - 1]) < 0.000001:
		return false
	return true

func _recompute() -> void:
	var n: int = exterior.size()
	if n < 3:
		area = 0.0
		bounds = Rect2()
		return

	# Bounding box
	var min_pt := exterior[0]
	var max_pt := exterior[0]
	for p in exterior:
		min_pt.x = minf(min_pt.x, p.x)
		min_pt.y = minf(min_pt.y, p.y)
		max_pt.x = maxf(max_pt.x, p.x)
		max_pt.y = maxf(max_pt.y, p.y)
	bounds = Rect2(min_pt, max_pt - min_pt)

	# Área neta = Área exterior - Suma de áreas de agujeros
	var ext_area: float = absf(_compute_signed_area(exterior))
	var holes_area: float = 0.0
	for h in agujeros:
		holes_area += absf(_compute_signed_area(h))
	area = maxf(ext_area - holes_area, 0.0)

## Triangula el WaterPolygon (contorno exterior y agujeros) generando una malla 2D limpia y conectada.
## Reglas:
## - Sin quads manuales, sin fans, sin ribbons, sin triángulos junction especiales.
## - Validación: área > epsilon, winding CCW estricto, índices válidos y múltiplos de 3.
## - Soldadura de vértices (no vértices duplicados, mantiene conectividad topológica).
## Retorna Dictionary con { "vertices_2d": PackedVector2Array, "indices": PackedInt32Array }.
func triangulate(p_epsilon: float = 0.0001) -> Dictionary:
	return triangulate_polygon_2d(exterior, agujeros, p_epsilon)

## Alias explícito
func triangulate_2d(p_epsilon: float = 0.0001) -> Dictionary:
	return triangulate_polygon_2d(exterior, agujeros, p_epsilon)

## Triangulación estática de un polígono 2D con agujeros
static func triangulate_polygon_2d(
	p_exterior: PackedVector2Array,
	p_agujeros: Array = [],
	p_epsilon: float = 0.0001
) -> Dictionary:
	if p_exterior.size() < 3:
		return {"vertices_2d": PackedVector2Array(), "indices": PackedInt32Array()}

	var clipped_polys: Array[PackedVector2Array] = [p_exterior]
	for h in p_agujeros:
		var h_pts: PackedVector2Array = h if h is PackedVector2Array else PackedVector2Array(h)
		if h_pts.size() < 3:
			continue
		var next_clipped: Array[PackedVector2Array] = []
		for poly in clipped_polys:
			var res = Geometry2D.clip_polygons(poly, h_pts)
			for r in res:
				if r.size() >= 3:
					next_clipped.append(r)
		clipped_polys = next_clipped

	return _triangulate_raw_polygons_to_mesh_2d(clipped_polys, p_epsilon)

## Triangulación combinada de múltiples WaterPolygon manteniendo conectividad
static func triangulate_multiple_2d(
	polygons: Array,
	p_epsilon: float = 0.0001
) -> Dictionary:
	var all_clipped: Array[PackedVector2Array] = []
	for poly_item in polygons:
		if poly_item is WaterPolygon:
			var clipped: Array[PackedVector2Array] = [poly_item.exterior]
			for h in poly_item.agujeros:
				var next_clipped: Array[PackedVector2Array] = []
				for p in clipped:
					var res = Geometry2D.clip_polygons(p, h)
					for r in res:
						if r.size() >= 3:
							next_clipped.append(r)
				clipped = next_clipped
			all_clipped.append_array(clipped)
		elif poly_item is PackedVector2Array:
			all_clipped.append(poly_item)

	return _triangulate_raw_polygons_to_mesh_2d(all_clipped, p_epsilon)

static func _triangulate_raw_polygons_to_mesh_2d(
	raw_polys: Array[PackedVector2Array],
	p_epsilon: float
) -> Dictionary:
	var raw_vertices := PackedVector2Array()
	var raw_indices := PackedInt32Array()
	var grid_map: Dictionary = {}
	var tolerance: float = maxf(p_epsilon * 0.5, 0.0001)
	var tol_sq: float = tolerance * tolerance

	for poly in raw_polys:
		if poly.size() < 3:
			continue

		# Triangulación algorítmica canónica de polígono simple (Ear Clipping en C++ nativo)
		# Prohibido: quads manuales, fans, ribbons o junctions especiales.
		var poly_indices := Geometry2D.triangulate_polygon(poly)
		if poly_indices.is_empty():
			continue

		var num_tris: int = poly_indices.size() / 3
		for t in range(num_tris):
			var i0_orig: int = poly_indices[t * 3]
			var i1_orig: int = poly_indices[t * 3 + 1]
			var i2_orig: int = poly_indices[t * 3 + 2]

			var p0: Vector2 = poly[i0_orig]
			var p1: Vector2 = poly[i1_orig]
			var p2: Vector2 = poly[i2_orig]

			# 1. Validación: puntos no degenerados
			if p0.distance_squared_to(p1) <= tol_sq or p1.distance_squared_to(p2) <= tol_sq or p2.distance_squared_to(p0) <= tol_sq:
				continue

			# 2. Validación: área > epsilon
			var cross: float = (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x)
			var tri_area: float = cross * 0.5
			if absf(tri_area) <= p_epsilon:
				continue

			# 3. Validación: winding consistente (CCW estricto en el plano 2D)
			if cross < 0.0:
				var temp := p1
				p1 = p2
				p2 = temp

			# 4. Soldar vértices: no vértices duplicados y preservar conectividad topológica
			var v0_idx: int = _get_or_add_welded_vertex(p0, raw_vertices, grid_map, tolerance, tol_sq)
			var v1_idx: int = _get_or_add_welded_vertex(p1, raw_vertices, grid_map, tolerance, tol_sq)
			var v2_idx: int = _get_or_add_welded_vertex(p2, raw_vertices, grid_map, tolerance, tol_sq)

			if v0_idx == v1_idx or v1_idx == v2_idx or v2_idx == v0_idx:
				continue

			raw_indices.append(v0_idx)
			raw_indices.append(v1_idx)
			raw_indices.append(v2_idx)

	# 5. Compactar vértices no referenciados y validar índices
	var used_map: Dictionary = {}
	var vertices_2d := PackedVector2Array()
	var indices := PackedInt32Array()

	for old_idx in raw_indices:
		if not used_map.has(old_idx):
			var new_idx: int = vertices_2d.size()
			vertices_2d.append(raw_vertices[old_idx])
			used_map[old_idx] = new_idx
		indices.append(used_map[old_idx])

	return {
		"vertices_2d": vertices_2d,
		"indices": indices,
		"vertices": vertices_2d
	}

static func _get_or_add_welded_vertex(
	pt: Vector2,
	vertices: PackedVector2Array,
	grid_map: Dictionary,
	tolerance: float,
	tol_sq: float
) -> int:
	var qx: int = int(round(pt.x / tolerance))
	var qy: int = int(round(pt.y / tolerance))

	# Buscar en la celda del hash y en sus 8 vecinas usando enteros (cero allocations de Vector2i)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var n_key: int = (int(qx + dx) * 73856093) ^ (int(qy + dy) * 19349663)
			if grid_map.has(n_key):
				var cand_idx: int = grid_map[n_key]
				if pt.distance_squared_to(vertices[cand_idx]) <= tol_sq:
					return cand_idx

	var new_idx: int = vertices.size()
	vertices.append(pt)
	var own_key: int = (int(qx) * 73856093) ^ (int(qy) * 19349663)
	grid_map[own_key] = new_idx
	return new_idx

# ==============================================================================
# PIPELINE PRINCIPAL DE GENERACIÓN DESDE CONTORNOS
# ==============================================================================

## Construye uno o varios WaterPolygon a partir de una lista de contornos (CleanContour / RawContour / PackedVector2Array).
## Pasos implementados:
## 1. Cálculo de área signada (Shoelace).
## 2. Detección de outer/hole mediante anidamiento jerárquico PIP (Point-In-Polygon).
## 3. Imposición de winding consistente (CCW para exterior, CW para agujeros).
## 4. Asociación de agujeros a su polígono exterior contenedor más cercano.
## 5. Confluencias unificadas quedan integradas en el mismo WaterPolygon continuo.
static func from_contours(contours: Array, minimum_polygon_area: float = 0.20) -> Array[WaterPolygon]:
	var rings: Array[Dictionary] = []

	# 1. Extraer y normalizar anillos de vértices (first != last)
	for c in contours:
		var pts: PackedVector2Array = PackedVector2Array()
		var comp_id: int = 0

		if c is Object and "points" in c:
			pts = c.points
			if "component_id" in c: comp_id = c.component_id
		elif c is PackedVector2Array:
			pts = c
		elif c is Array:
			for p in c:
				if p is Vector2: pts.append(p)
				elif p is Vector3: pts.append(Vector2(p.x, p.z))

		if pts.size() < 3:
			continue

		# Anillo first != last
		if pts.size() > 1 and pts[0].distance_squared_to(pts[-1]) < 0.000001:
			pts.remove_at(pts.size() - 1)

		if pts.size() < 3:
			continue

		var s_area: float = _compute_signed_area(pts)
		if absf(s_area) < maxf(minimum_polygon_area, 0.0001):
			continue

		var b := _compute_bounds(pts)
		var test_pt := _compute_interior_point(pts)

		rings.append({
			"points": pts,
			"signed_area": s_area,
			"abs_area": absf(s_area),
			"bounds": b,
			"test_pt": test_pt,
			"component_id": comp_id
		})

	var num_rings: int = rings.size()
	if num_rings == 0:
		return []

	# 2. Determinar profundidad de anidamiento PIP (Containment Parity)
	# Si un anillo está contenido dentro de un número PAR de otros anillos (0, 2...) -> EXTERIOR
	# Si está contenido dentro de un número IMPAR (1, 3...) -> AGUJERO / ISLA
	for i in range(num_rings):
		var r_i: Dictionary = rings[i]
		var containment_count: int = 0
		var parents: Array[int] = []

		for j in range(num_rings):
			if i == j:
				continue
			var r_j: Dictionary = rings[j]
			if r_j["bounds"].encloses(r_i["bounds"]) or r_j["bounds"].intersects(r_i["bounds"]):
				if Geometry2D.is_point_in_polygon(r_i["test_pt"], r_j["points"]):
					containment_count += 1
					parents.append(j)

		r_i["containment_count"] = containment_count
		r_i["parents"] = parents
		# Paridad: par = exterior (0, 2), impar = agujero (1, 3)
		r_i["is_hole"] = (containment_count % 2 == 1)

	# 3. Separar y aplicar Winding consistente
	var outers: Array[Dictionary] = []
	var holes_list: Array[Dictionary] = []

	for r in rings:
		if not r["is_hole"]:
			# Exterior: Winding CCW (área signada > 0)
			r["points"] = _enforce_winding(r["points"], false)
			outers.append(r)
		else:
			# Agujero: Winding CW (área signada < 0)
			r["points"] = _enforce_winding(r["points"], true)
			holes_list.append(r)

	# 4. Crear instancias de WaterPolygon para cada contorno exterior
	var polygons: Array[WaterPolygon] = []
	var next_id: int = 1

	for out_dict in outers:
		var c_id: int = out_dict["component_id"] if out_dict["component_id"] > 0 else next_id
		next_id = maxi(next_id, c_id + 1)
		var wp := WaterPolygon.new(out_dict["points"], [], c_id)
		polygons.append(wp)
		out_dict["instance"] = wp

	# 5. Asignar cada agujero al polígono exterior contenedor más inmediato (menor área)
	for h_dict in holes_list:
		var best_parent_poly: WaterPolygon = null
		var min_parent_area: float = INF

		for out_dict in outers:
			var wp: WaterPolygon = out_dict["instance"]
			if wp.bounds.encloses(h_dict["bounds"]) or wp.bounds.intersects(h_dict["bounds"]):
				if Geometry2D.is_point_in_polygon(h_dict["test_pt"], wp.exterior):
					if out_dict["abs_area"] < min_parent_area:
						min_parent_area = out_dict["abs_area"]
						best_parent_poly = wp

		if best_parent_poly != null:
			best_parent_poly.add_hole(h_dict["points"])

	return polygons

# --- Métodos auxiliares de geometría y cálculo ---

static func _compute_signed_area(pts: PackedVector2Array) -> float:
	var n: int = pts.size()
	if n < 3:
		return 0.0
	var sum: float = 0.0
	for i in range(n):
		var next_idx: int = (i + 1) % n
		sum += pts[i].x * pts[next_idx].y - pts[next_idx].x * pts[i].y
	return sum * 0.5

static func _compute_bounds(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var min_pt := pts[0]
	var max_pt := pts[0]
	for p in pts:
		min_pt.x = minf(min_pt.x, p.x)
		min_pt.y = minf(min_pt.y, p.y)
		max_pt.x = maxf(max_pt.x, p.x)
		max_pt.y = maxf(max_pt.y, p.y)
	return Rect2(min_pt, max_pt - min_pt)

## Obtiene un punto interior representativo del polígono para tests PIP robustos
static func _compute_interior_point(pts: PackedVector2Array) -> Vector2:
	var n: int = pts.size()
	if n < 3:
		return Vector2.ZERO

	# Buscar una terna convexa donde el baricentro del triángulo esté dentro del polígono
	var s_area: float = _compute_signed_area(pts)
	var is_ccw: bool = (s_area > 0.0)

	for i in range(n):
		var p_prev: Vector2 = pts[(i - 1 + n) % n]
		var p_curr: Vector2 = pts[i]
		var p_next: Vector2 = pts[(i + 1) % n]

		# 2D cross product
		var v1: Vector2 = p_curr - p_prev
		var v2: Vector2 = p_next - p_curr
		var cross: float = v1.x * v2.y - v1.y * v2.x

		# Si el giro coincide con el signo del polígono, es una esquina convexa
		if (is_ccw and cross > 0.0001) or (not is_ccw and cross < -0.0001):
			var mid: Vector2 = (p_prev + p_curr + p_next) / 3.0
			if Geometry2D.is_point_in_polygon(mid, pts):
				return mid

	# Fallback a punto ligeramente desplazado hacia el interior desde el primer vértice
	var p0: Vector2 = pts[0]
	var p1: Vector2 = pts[1]
	var edge_mid: Vector2 = (p0 + p1) * 0.5
	var edge_dir: Vector2 = (p1 - p0).normalized()
	var normal: Vector2 = Vector2(-edge_dir.y, edge_dir.x) if is_ccw else Vector2(edge_dir.y, -edge_dir.x)
	var candidate: Vector2 = edge_mid + normal * 0.05
	if Geometry2D.is_point_in_polygon(candidate, pts):
		return candidate

	return pts[0]

## Impone winding: CCW (área > 0) para exteriores (is_hole = false), CW (área < 0) para agujeros (is_hole = true)
static func _enforce_winding(pts: PackedVector2Array, for_hole: bool) -> PackedVector2Array:
	var s_area: float = _compute_signed_area(pts)
	var is_ccw: bool = (s_area > 0.0)
	var target_ccw: bool = not for_hole

	if is_ccw != target_ccw:
		var reversed: PackedVector2Array = PackedVector2Array()
		var n: int = pts.size()
		for i in range(n - 1, -1, -1):
			reversed.append(pts[i])
		return reversed

	return pts

func to_dict() -> Dictionary:
	var holes_dicts: Array = []
	for h in agujeros:
		holes_dicts.append(h)
	return {
		"component_id": component_id,
		"exterior_vertices": exterior.size(),
		"holes_count": agujeros.size(),
		"net_area": area,
		"bounds": bounds,
		"exterior": exterior,
		"agujeros": holes_dicts
	}

func _to_string() -> String:
	return "WaterPolygon(comp=%d, ext_pts=%d, holes=%d, net_area=%.2f)" % [
		component_id, exterior.size(), agujeros.size(), area
	]
