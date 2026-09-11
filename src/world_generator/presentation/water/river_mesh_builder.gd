class_name RiverMeshBuilder
extends RefCounted

## Constructor de geometría de cinta de agua para tramos de río y confluencias.
## Calcula la cota de la superficie de agua independientemente del lecho del terreno,
## respetando el encajonamiento en orillas (water_y <= bank_y) y codificando vectores de flujo en UV2.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

static func build_river_surface(river: Variant, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var raw_pts: Array = river.points if (river is River or "points" in river) else river.get("points", [])
	if raw_pts.size() < 2:
		return null

	var raw_widths: Array = river.widths if (river is River or "widths" in river) else river.get("widths", [])
	var raw_depths: Array = river.depths if (river is River or "depths" in river) else river.get("depths", [])

	# Resampling suave con Catmull-Rom
	var smooth_data := _catmull_rom_resample(raw_pts, raw_widths, raw_depths, 4)
	var pts: Array[Vector3] = smooth_data["points"]
	var widths: Array[float] = smooth_data["widths"]
	var depths: Array[float] = smooth_data["depths"]
	var total_pts: int = pts.size()
	if total_pts < 2:
		return null

	var surf = _WaterSurfaceDataScript.new()
	var accumulated_dist: float = 0.0
	var cell_size: float = maxf(profile.cell_size, 0.01)

	for j in range(total_pts):
		var p: Vector3 = pts[j]
		if j > 0:
			accumulated_dist += pts[j].distance_to(pts[j - 1])

		# Tangente y perpendicular en el plano XZ
		var tangent: Vector3
		if j == 0:
			tangent = (pts[1] - pts[0]).normalized()
		elif j == total_pts - 1:
			tangent = (pts[j] - pts[j - 1]).normalized()
		else:
			tangent = (pts[j + 1] - pts[j - 1]).normalized()
		tangent.y = 0.0
		tangent = tangent.normalized() if tangent.length_squared() >= 0.0001 else Vector3(0, 0, 1)

		var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		var flow_vec := Vector2(tangent.x, tangent.z).normalized()

		var w: float = widths[j] / cell_size
		var half_w: float = w * 0.5
		var actual_depth: float = depths[j]

		# Muestreo del lecho y orillas
		var lx: float = p.x + perp.x * half_w
		var lz: float = p.z + perp.z * half_w
		var rx: float = p.x - perp.x * half_w
		var rz: float = p.z - perp.z * half_w

		var bed_l: float = _sample_terrain(result, lx, lz)
		var bed_r: float = _sample_terrain(result, rx, rz)
		var bank_l: float = _sample_terrain(result, lx + perp.x * 0.5, lz + perp.z * 0.5)
		var bank_r: float = _sample_terrain(result, rx - perp.x * 0.5, rz - perp.z * 0.5)

		# Cota del agua: lecho + profundidad calculada, limitada a no desbordar sobre la orilla seca
		var ly: float = minf(bed_l + actual_depth, bank_l + 0.02)
		var ry: float = minf(bed_r + actual_depth, bank_r + 0.02)

		# Garantía de columna de agua positiva sobre el lecho tallado
		ly = maxf(ly, bed_l + 0.015)
		ry = maxf(ry, bed_r + 0.015)

		# UVs: transversal [0, 1] y longitudinal en metros
		var u_coord: float = accumulated_dist
		var col: Color = profile.water_color_river

		var idx_l: int = surf.add_vertex(Vector3(lx, ly, lz), Vector3.UP, Vector2(0.0, u_coord), flow_vec, col)
		var idx_r: int = surf.add_vertex(Vector3(rx, ry, rz), Vector3.UP, Vector2(1.0, u_coord), flow_vec, col)

		if j > 0:
			var prev_l: int = idx_l - 2
			var prev_r: int = idx_r - 2
			surf.add_triangle(prev_l, prev_r, idx_l)
			surf.add_triangle(prev_r, idx_r, idx_l)

	return surf

## Construye un parche geométrico en la confluencia para evitar grietas visuales entre ribbons
static func build_confluence_patch(conf: Dictionary, result: WorldResult, profile: WorldProfile) -> RefCounted:
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

static func _catmull_rom_resample(raw_pts: Array, raw_w: Array, raw_d: Array, sub_divs: int = 4) -> Dictionary:
	var pts_res: Array[Vector3] = []
	var w_res: Array[float] = []
	var d_res: Array[float] = []
	var n: int = raw_pts.size()
	if n < 2:
		return {"points": pts_res, "widths": w_res, "depths": d_res}

	for i in range(n - 1):
		var p0: Vector3 = raw_pts[maxi(i - 1, 0)]
		var p1: Vector3 = raw_pts[i]
		var p2: Vector3 = raw_pts[i + 1]
		var p3: Vector3 = raw_pts[mini(i + 2, n - 1)]

		var w0: float = float(raw_w[maxi(i - 1, 0)]) if maxi(i - 1, 0) < raw_w.size() else 0.8
		var w1: float = float(raw_w[i]) if i < raw_w.size() else 0.8
		var w2: float = float(raw_w[i + 1]) if i + 1 < raw_w.size() else 0.8
		var w3: float = float(raw_w[mini(i + 2, n - 1)]) if mini(i + 2, n - 1) < raw_w.size() else 0.8

		var d0: float = float(raw_d[maxi(i - 1, 0)]) if maxi(i - 1, 0) < raw_d.size() else 0.2
		var d1: float = float(raw_d[i]) if i < raw_d.size() else 0.2
		var d2: float = float(raw_d[i + 1]) if i + 1 < raw_d.size() else 0.2
		var d3: float = float(raw_d[mini(i + 2, n - 1)]) if mini(i + 2, n - 1) < raw_d.size() else 0.2

		for step in range(sub_divs):
			var t: float = float(step) / float(sub_divs)
			var t2: float = t * t
			var t3: float = t2 * t
			var pt: Vector3 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			var w: float = 0.5 * ((2.0 * w1) + (-w0 + w2) * t + (2.0 * w0 - 5.0 * w1 + 4.0 * w2 - w3) * t2 + (-w0 + 3.0 * w1 - 3.0 * w2 + w3) * t3)
			var d: float = 0.5 * ((2.0 * d1) + (-d0 + d2) * t + (2.0 * d0 - 5.0 * d1 + 4.0 * d2 - d3) * t2 + (-d0 + 3.0 * d1 - 3.0 * d2 + d3) * t3)
			pts_res.append(pt)
			w_res.append(maxf(w, 0.2))
			d_res.append(maxf(d, 0.05))

	pts_res.append(raw_pts[n - 1] as Vector3)
	w_res.append(maxf(float(raw_w[-1]) if not raw_w.is_empty() else 0.8, 0.2))
	d_res.append(maxf(float(raw_d[-1]) if not raw_d.is_empty() else 0.2, 0.05))
	return {"points": pts_res, "widths": w_res, "depths": d_res}
