class_name RiverMeshBuilder
extends RefCounted

## Constructor robusto de mallas de agua longitudinales (Quad Strips).
## Elimina deformaciones, picos de sierra y cortes de terreno:
## 1. Suavizado gaussiano del centroide para eliminar el efecto "escalera" del D8.
## 2. Tangentes continuas y perpendiculares con miter limitado.
## 3. Cota transversal plana (water_y idéntica en izquierda y derecha) para evitar que el terreno perfore la lámina de agua.
## 4. Winding order y triangulación estricta en cuadriláteros continuos.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

static func build_river_surface(river: Variant, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var raw_pts: Array = river.points if (river is River or "points" in river) else river.get("points", [])
	if raw_pts.size() < 2:
		return null

	var raw_widths: Array = river.widths if (river is River or "widths" in river) else river.get("widths", [])
	var raw_depths: Array = river.depths if (river is River or "depths" in river) else river.get("depths", [])
	var hydro = result.hydrology if result != null else null

	# 1. Limpieza y suavizado gaussiano del centroide para eliminar saltos angulares de 90° del D8
	var smooth_data := _smooth_and_resample_centerline(raw_pts, raw_widths, raw_depths, profile)
	var pts: Array[Vector3] = smooth_data["points"]
	var widths: Array[float] = smooth_data["widths"]
	var depths: Array[float] = smooth_data["depths"]
	var total_pts: int = pts.size()
	if total_pts < 2:
		return null

	var surf = _WaterSurfaceDataScript.new()
	var cell_size: float = maxf(profile.cell_size, 0.01)

	var shallow_col: Color = profile.water_color_shallow
	var river_col: Color = profile.water_color_river
	var lake_col: Color = profile.water_color_lake

	# 2. Calcular tangentes suavizadas a lo largo del centroide
	var tangents: Array[Vector3] = []
	for j in range(total_pts):
		var t: Vector3
		if j == 0:
			t = (pts[1] - pts[0]).normalized()
		elif j == total_pts - 1:
			t = (pts[j] - pts[j - 1]).normalized()
		else:
			var v_in: Vector3 = (pts[j] - pts[j - 1]).normalized()
			var v_out: Vector3 = (pts[j + 1] - pts[j]).normalized()
			t = (v_in + v_out).normalized()
			if t.length_squared() < 0.001:
				t = v_out
		t.y = 0.0
		t = t.normalized() if t.length_squared() >= 0.0001 else Vector3(0, 0, 1)
		tangents.append(t)

	# 3. Generar las estaciones izquierda y derecha
	var left_pts: Array[Vector3] = []
	var right_pts: Array[Vector3] = []
	var water_heights: Array[float] = []

	var prev_water_y: float = 99999.0

	for j in range(total_pts):
		var p: Vector3 = pts[j]
		var t: Vector3 = tangents[j]
		var side := Vector3(-t.z, 0.0, t.x).normalized()

		# Control de miter en curvas para evitar ensanchamientos o picos bruscos
		var miter_scale: float = 1.0
		if j > 0 and j < total_pts - 1:
			var v_in: Vector3 = (pts[j] - pts[j - 1]).normalized()
			var v_out: Vector3 = (pts[j + 1] - pts[j]).normalized()
			var dot: float = clampf(v_in.dot(v_out), -0.5, 1.0)
			miter_scale = clampf(1.0 / maxf(sqrt((1.0 + dot) * 0.5), 0.707), 1.0, 1.25)

		var half_w: float = (widths[j] / cell_size) * 0.5 * miter_scale

		var lx: float = p.x + side.x * half_w
		var lz: float = p.z + side.z * half_w
		var rx: float = p.x - side.x * half_w
		var rz: float = p.z - side.z * half_w

		# Muestrear el lecho y bordes
		var ground_c: float = _sample_terrain(result, p.x, p.z)
		var ground_l: float = _sample_terrain(result, lx, lz)
		var ground_r: float = _sample_terrain(result, rx, rz)

		# Cota de agua transversalmente PLANA:
		# Se apoya en la cota del lecho más la profundidad o sobre el terreno local para no quedar nunca enterrada
		var max_ground: float = maxf(ground_c, maxf(ground_l, ground_r))
		var base_depth: float = maxf(depths[j], 0.12)
		var water_y: float = maxf(p.y + 0.03, max_ground + 0.025)

		# Nivelar con lago si el tramo entra en cuenca lacustre
		if hydro != null:
			var grid_pos := Vector2i(clampi(int(round(p.x)), 0, profile.width - 1), clampi(int(round(p.z)), 0, profile.height - 1))
			if hydro.is_lake(grid_pos):
				var l_data: Dictionary = hydro.get_cell_data(grid_pos)
				if l_data.has("water_height"):
					water_y = maxf(water_y, float(l_data["water_height"]))

		left_pts.append(Vector3(lx, water_y, lz))
		right_pts.append(Vector3(rx, water_y, rz))
		water_heights.append(water_y)

	# 4. Construir la malla en franjas regulares continuas
	for j in range(total_pts):
		var prog: float = float(j) / float(maxi(total_pts - 1, 1))
		var flow_vec := Vector2(tangents[j].x, tangents[j].z)

		var col: Color
		if prog < 0.35:
			col = shallow_col.lerp(river_col, prog / 0.35)
		else:
			col = river_col.lerp(lake_col, (prog - 0.35) / 0.65)
		col.a = clampf(0.85 + prog * 0.10, 0.0, 0.98)

		var idx_l: int = surf.add_vertex(left_pts[j], Vector3.UP, Vector2(0.0, prog), flow_vec, col)
		var idx_r: int = surf.add_vertex(right_pts[j], Vector3.UP, Vector2(1.0, prog), flow_vec, col)

		if j > 0:
			var prev_l: int = idx_l - 2
			var prev_r: int = idx_r - 2

			# Triángulo 1 (PrevL, PrevR, CurrL)
			surf.add_triangle(prev_l, prev_r, idx_l)
			# Triángulo 2 (PrevR, CurrR, CurrL)
			surf.add_triangle(prev_r, idx_r, idx_l)

	return surf

static func build_confluence_patch(_conf: Dictionary, _result: WorldResult, _profile: WorldProfile) -> RefCounted:
	return null

## Suaviza el centroide del río mediante filtrado gaussiano para eliminar saltos en dientes de sierra
static func _smooth_and_resample_centerline(raw_pts: Array, raw_w: Array, raw_d: Array, profile: WorldProfile) -> Dictionary:
	var n: int = raw_pts.size()
	if n < 2:
		return {"points": raw_pts, "widths": raw_w, "depths": raw_d}

	# 1. Filtrar puntos duplicados exactos
	var clean_pts: Array[Vector3] = []
	var clean_w: Array[float] = []
	var clean_d: Array[float] = []

	for i in range(n):
		var p: Vector3 = raw_pts[i] as Vector3
		var w: float = float(raw_w[i]) if i < raw_w.size() else 1.2
		var d: float = float(raw_d[i]) if i < raw_d.size() else 0.25

		if clean_pts.is_empty():
			clean_pts.append(p)
			clean_w.append(w)
			clean_d.append(d)
		else:
			if p.distance_to(clean_pts[-1]) >= 0.02:
				clean_pts.append(p)
				clean_w.append(w)
				clean_d.append(d)

	var count: int = clean_pts.size()
	if count < 3:
		return {"points": clean_pts, "widths": clean_w, "depths": clean_d}

	# 2. Filtrado gaussiano de 3 pasadas sobre (X, Z) manteniendo intactos los extremos (source y outlet)
	var smoothed_pts := clean_pts.duplicate()
	for pass_idx in range(3):
		var temp := smoothed_pts.duplicate()
		for i in range(1, count - 1):
			smoothed_pts[i].x = 0.25 * temp[i - 1].x + 0.5 * temp[i].x + 0.25 * temp[i + 1].x
			smoothed_pts[i].z = 0.25 * temp[i - 1].z + 0.5 * temp[i].z + 0.25 * temp[i + 1].z

	# 3. Interpolación Catmull-Rom sobre los puntos ya filtrados con paso uniforme (sub_divs = 2)
	var final_pts: Array[Vector3] = []
	var final_w: Array[float] = []
	var final_d: Array[float] = []

	for i in range(count - 1):
		var p0: Vector3 = smoothed_pts[maxi(i - 1, 0)]
		var p1: Vector3 = smoothed_pts[i]
		var p2: Vector3 = smoothed_pts[i + 1]
		var p3: Vector3 = smoothed_pts[mini(i + 2, count - 1)]

		var w1: float = clean_w[i]
		var w2: float = clean_w[i + 1]
		var d1: float = clean_d[i]
		var d2: float = clean_d[i + 1]

		for step in range(2):
			var t: float = float(step) * 0.5
			var t2: float = t * t
			var t3: float = t2 * t
			var pt: Vector3 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			var w_val: float = lerpf(w1, w2, t)
			var d_val: float = lerpf(d1, d2, t)

			final_pts.append(pt)
			final_w.append(maxf(w_val, 0.4))
			final_d.append(maxf(d_val, 0.08))

	final_pts.append(smoothed_pts[-1])
	final_w.append(maxf(clean_w[-1], 0.4))
	final_d.append(maxf(clean_d[-1], 0.08))

	return {"points": final_pts, "widths": final_w, "depths": final_d}

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
