class_name LakeMeshBuilder
extends RefCounted

## Constructor de geometría de superficie plana horizontal para lagos y depresiones.
## Genera una malla continua a la cota exacta lake.water_height sin deformaciones ni inclinaciones,
## recortando las orillas mediante intersección de contorno con el talud perimetral.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

static func build_lake_surface(lake: Dictionary, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var lake_cells: Array = lake.get("cells", [])
	if lake_cells.is_empty():
		return null

	var water_y: float = float(lake.get("water_height", 0.0))
	var lake_set: Dictionary = {}
	for c in lake_cells:
		lake_set[c] = true

	var surf = _WaterSurfaceDataScript.new()
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	var cell_size: float = profile.cell_size if profile != null else 1.0

	var vertex_cache: Dictionary = {}

	# Identificar quads que tocan las celdas del lago
	var quads_to_check: Dictionary = {}
	for cp in lake_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx: int = cp.x + dx
				var qy: int = cp.y + dy
				if qx >= 0 and qx < w - 1 and qy >= 0 and qy < h - 1:
					quads_to_check[Vector2i(qx, qy)] = true

	var col: Color = profile.water_color_lake if profile != null else Color("#073b5e")
	var flow: Vector2 = Vector2.ZERO  # Lago en calma

	for qpos in quads_to_check.keys():
		var c0: Vector2i = qpos
		var c1: Vector2i = qpos + Vector2i(1, 0)
		var c2: Vector2i = qpos + Vector2i(1, 1)
		var c3: Vector2i = qpos + Vector2i(0, 1)

		var in_basin: bool = lake_set.has(c0) or lake_set.has(c1) or lake_set.has(c2) or lake_set.has(c3)
		if not in_basin:
			continue

		var h0: float = result.get_cell(c0).height
		var h1: float = result.get_cell(c1).height
		var h2: float = result.get_cell(c2).height
		var h3: float = result.get_cell(c3).height

		# Distancia del terreno a la lámina de agua (d <= 0 sumergido, d > 0 tierra seca)
		var d0: float = (h0 - water_y) if lake_set.has(c0) else maxf(h0 - water_y, 0.001)
		var d1: float = (h1 - water_y) if lake_set.has(c1) else maxf(h1 - water_y, 0.001)
		var d2: float = (h2 - water_y) if lake_set.has(c2) else maxf(h2 - water_y, 0.001)
		var d3: float = (h3 - water_y) if lake_set.has(c3) else maxf(h3 - water_y, 0.001)

		# Si todos los vértices son tierra seca, no hay agua en esta celda
		if d0 > 0.0 and d1 > 0.0 and d2 > 0.0 and d3 > 0.0:
			continue

		var p0_2d := Vector2(float(c0.x), float(c0.y)) * cell_size
		var p1_2d := Vector2(float(c1.x), float(c1.y)) * cell_size
		var p2_2d := Vector2(float(c2.x), float(c2.y)) * cell_size
		var p3_2d := Vector2(float(c3.x), float(c3.y)) * cell_size

		# 1. Caso interior pleno: los 4 vértices están sumergidos bajo el agua
		if d0 <= 0.0 and d1 <= 0.0 and d2 <= 0.0 and d3 <= 0.0:
			var i0: int = _get_or_add_lake_vertex(surf, p0_2d, water_y, col, flow, vertex_cache)
			var i1: int = _get_or_add_lake_vertex(surf, p1_2d, water_y, col, flow, vertex_cache)
			var i2: int = _get_or_add_lake_vertex(surf, p2_2d, water_y, col, flow, vertex_cache)
			var i3: int = _get_or_add_lake_vertex(surf, p3_2d, water_y, col, flow, vertex_cache)

			surf.add_triangle(i0, i1, i2)
			surf.add_triangle(i0, i2, i3)
			continue

		# 2. Caso frontera de orilla: recortar el polígono de agua donde el terreno cruza water_y
		var corners: Array[Vector2] = [p0_2d, p1_2d, p2_2d, p3_2d]
		var d_vals: Array[float] = [d0, d1, d2, d3]
		var poly_pts: Array[Vector2] = []

		for k in range(4):
			var k_next: int = (k + 1) % 4
			var c_curr: Vector2 = corners[k]
			var c_next: Vector2 = corners[k_next]
			var d_curr: float = d_vals[k]
			var d_next: float = d_vals[k_next]

			if d_curr <= 0.0:
				poly_pts.append(c_curr)

			if (d_curr <= 0.0 and d_next > 0.0) or (d_curr > 0.0 and d_next <= 0.0):
				var span: float = d_next - d_curr
				var frac: float = clampf(-d_curr / span, 0.0, 1.0) if absf(span) > 0.00001 else 0.5
				var edge_cross: Vector2 = c_curr.lerp(c_next, frac)
				poly_pts.append(edge_cross)

		var num_pts: int = poly_pts.size()
		if num_pts < 3:
			continue

		var indices_in_poly: Array[int] = []
		indices_in_poly.resize(num_pts)
		for k in range(num_pts):
			indices_in_poly[k] = _get_or_add_lake_vertex(surf, poly_pts[k], water_y, col, flow, vertex_cache)

		for k in range(1, num_pts - 1):
			var idx0: int = indices_in_poly[0]
			var idx1: int = indices_in_poly[k]
			var idx2: int = indices_in_poly[k + 1]
			if idx0 != idx1 and idx1 != idx2 and idx2 != idx0:
				surf.add_triangle(idx0, idx1, idx2)

	return surf

static func _get_or_add_lake_vertex(
	surf: RefCounted,
	p2: Vector2,
	water_y: float,
	col: Color,
	flow: Vector2,
	vertex_cache: Dictionary
) -> int:
	var qx: int = int(round(p2.x * 200.0))
	var qz: int = int(round(p2.y * 200.0))
	var key: int = (qx << 32) | (qz & 0xFFFFFFFF)
	if vertex_cache.has(key):
		return vertex_cache[key]

	var v_pos := Vector3(p2.x, water_y, p2.y)
	var idx: int = surf.add_vertex(v_pos, Vector3.UP, p2, flow, col)
	vertex_cache[key] = idx
	return idx
