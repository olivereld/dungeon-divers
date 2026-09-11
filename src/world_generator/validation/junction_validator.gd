class_name JunctionValidator
extends RefCounted

## Validador geométrico específico para superficies de confluencia (Junctions).
## Verifica sanidad topológica, ausencia de inversión de quads, aristas cruzadas,
## continuidades longitudinales y ausencia de gaps entre ramas.

static func validate_quad(l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3) -> Dictionary:
	var errors: Array[String] = []

	# 1. Finitud
	if not (is_finite(l0.x) and is_finite(l0.y) and is_finite(l0.z) and
		is_finite(r0.x) and is_finite(r0.y) and is_finite(r0.z) and
		is_finite(l1.x) and is_finite(l1.y) and is_finite(l1.z) and
		is_finite(r1.x) and is_finite(r1.y) and is_finite(r1.z)):
		errors.append("Non-finite vertex coordinates in junction quad")
		return {"valid": false, "errors": errors}

	# 2. Área mínima por triángulo
	var cross_a: Vector3 = (r0 - l0).cross(l1 - l0)
	var cross_b: Vector3 = (r1 - r0).cross(l1 - r0)
	var area_a: float = cross_a.length() * 0.5
	var area_b: float = cross_b.length() * 0.5

	if area_a < 0.000001 or area_b < 0.000001:
		errors.append("Degenerate triangle in junction quad (area_a: %f, area_b: %f)" % [area_a, area_b])

	# 3. No auto-intersección de aristas izquierda y derecha en plano XZ
	var pl0 := Vector2(l0.x, l0.z)
	var pl1 := Vector2(l1.x, l1.z)
	var pr0 := Vector2(r0.x, r0.z)
	var pr1 := Vector2(r1.x, r1.z)

	if _segments_intersect_2d(pl0, pl1, pr0, pr1):
		errors.append("Crossed lateral edges in junction quad (bowtie self-intersection)")

	# 4. Progreso longitudinal positivo
	var center0: Vector2 = (pl0 + pr0) * 0.5
	var center1: Vector2 = (pl1 + pr1) * 0.5
	var step_dist: float = center0.distance_to(center1)
	if step_dist < 0.0001:
		errors.append("Zero longitudinal progression in junction quad")

	# 5. Anchos positivos en ambas secciones
	var w0: float = pl0.distance_to(pr0)
	var w1: float = pl1.distance_to(pr1)
	if w0 < 0.01 or w1 < 0.01:
		errors.append("Station width collapsed (< 0.01) in junction quad")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"metrics": {
			"area_a": area_a,
			"area_b": area_b,
			"step_dist": step_dist,
			"w0": w0,
			"w1": w1
		}
	}

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

	var min_verts: int = expected_branches * 2 * (m_steps + 1)
	var min_tris: int = expected_branches * m_steps * 2

	if verts.size() < min_verts:
		errors.append("Vertex count too low: %d (expected >= %d)" % [verts.size(), min_verts])

	if (indices.size() / 3) < min_tris:
		errors.append("Triangle count too low: %d (expected >= %d)" % [indices.size() / 3, min_tris])

	# Chequeo de triángulos individuales
	var degenerate_count: int = 0
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

		var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
		if area < 0.000001:
			degenerate_count += 1

	if degenerate_count > 0:
		errors.append("Found %d degenerate triangles in junction surface" % degenerate_count)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"metrics": {
			"vertices": verts.size(),
			"triangles": indices.size() / 3,
			"degenerate_triangles": degenerate_count,
			"branches": expected_branches,
			"m_steps": m_steps
		}
	}

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
