class_name WaterPresentationValidation
extends RefCounted

## Validador formal para la superficie de agua renderizada.
## Comprueba sanidad geométrica, ausencia de triángulos degenerados, slivers y cotas finitas.

const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")

static func validate(result: WorldResult, profile: WorldProfile) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var water_node = _WaterRendererScript.build_water_node(result, profile)
	if water_node == null:
		return {"valid": true, "errors": [], "warnings": ["No water surface generated"], "metrics": {}}

	var mi: MeshInstance3D = water_node.get_node_or_null("UnifiedWaterSurface")
	if mi == null or mi.mesh == null:
		errors.append("UnifiedWaterSurface MeshInstance3D or Mesh is null")
		water_node.free()
		return {"valid": false, "errors": errors, "warnings": warnings, "metrics": {}}

	var mesh: ArrayMesh = mi.mesh
	if mesh.get_surface_count() == 0:
		errors.append("Water mesh has zero surfaces")
		water_node.free()
		return {"valid": false, "errors": errors, "warnings": warnings, "metrics": {}}

	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# 1. Chequeo de NaN e Inf
	for v in verts:
		if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.y) or is_inf(v.z):
			errors.append("Found NaN or Inf in water mesh vertices")
			break

	# 2. Chequeo de triángulos degenerados y slivers extremos
	var degenerate_count: int = 0
	var sliver_count: int = 0

	for i in range(0, indices.size(), 3):
		if i + 2 < indices.size():
			var i0: int = indices[i]
			var i1: int = indices[i + 1]
			var i2: int = indices[i + 2]
			if i0 == i1 or i1 == i2 or i0 == i2:
				degenerate_count += 1
				continue

			var v0: Vector3 = verts[i0]
			var v1: Vector3 = verts[i1]
			var v2: Vector3 = verts[i2]

			var a: float = v0.distance_to(v1)
			var b: float = v1.distance_to(v2)
			var c: float = v2.distance_to(v0)

			var max_edge: float = maxf(a, maxf(b, c))
			var min_edge: float = minf(a, minf(b, c))

			# Triangle area via cross product
			var cross_prod: Vector3 = (v1 - v0).cross(v2 - v0)
			var area: float = cross_prod.length() * 0.5

			if area < 0.0001:
				degenerate_count += 1
			elif max_edge > 0.4 and (area / (max_edge * max_edge)) < 0.02:
				# Sliver extremo (relación de aspecto > 25:1)
				sliver_count += 1

	if degenerate_count > 0:
		errors.append("Found %d degenerate triangles in water surface mesh" % degenerate_count)
	if sliver_count > 0:
		warnings.append("Found %d sliver triangles in water surface mesh" % sliver_count)

	water_node.free()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"metrics": {
			"total_vertices": verts.size(),
			"total_triangles": indices.size() / 3,
			"degenerate_triangles": degenerate_count,
			"sliver_triangles": sliver_count
		}
	}
