class_name WaterMeshBuilder
extends RefCounted

## Builder canónico y unificado de mallas de agua (WaterMeshBuilder).
## Construye geometría de agua compartida idénticamente entre mundos globales (laboratorio, gameplay)
## y chunks en streaming.
##
## Principios:
## 1. Algoritmo canónico unificado:
##    - Genera quads planares (2 triángulos, 4 vértices) exactamente para las celdas hidráulicamente activas (water_cells).
##    - Genera quads verticales de cascada (waterfall quads) en bordes con desnivel hidráulico superior a waterfall_height_threshold.
##    - Las celdas secas no emiten geometría de agua redundante.
## 2. Unificación absoluta entre Global y Chunk:
##    - Cero bifurcaciones algorítmicas ('if is_chunk').
##    - Mismas cotas, mismas normales, mismo shader, mismo empaquetado.
##    - La única diferencia es contextual: origen, dimensiones y bounds.
## 3. Invarianza hidráulica estricta:
##    - hydro.water_cells permanece 100% inmutable durante toda la construcción.
##    - WorldCell.height nunca es alterado por el builder.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _WaterTopologyScript    = preload("res://src/world_generator/presentation/water/water_topology.gd")

## API canonica: construye el ArrayMesh global del agua
static func build_mesh(result: WorldResult, profile = null) -> ArrayMesh:
	var surf: WaterSurfaceData = build_water_surface(result, profile)
	if surf == null:
		return null
	return surf.to_array_mesh()

## Analiza y retorna la topologia hidraulica formal de water_cells
static func build_topology(result: WorldResult) -> WaterTopology:
	if result == null or result.hydrology == null:
		return null
	return _WaterTopologyScript.analyze(result.hydrology.water_cells, result.dimensions.x, result.dimensions.y)

## Construye la superficie global del agua cubriendo la grilla completa (1:1 con TerrainMesh)
static func build_water_surface(result: WorldResult, profile = null) -> WaterSurfaceData:
	if result == null or result.hydrology == null:
		return null

	var hydro: HydrologyResult = result.hydrology
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	if w <= 1 or h <= 1:
		return null
	if hydro.water_cells.is_empty():
		return null

	var is_chunk: bool = ("seam_cells" in result) or (result.has_method("get_core_bounds"))
	var origin := Vector2i.ZERO
	if "core_bounds" in result:
		origin = result.core_bounds.position

	var cell_size: float = 1.0
	if profile != null and "cell_size" in profile:
		cell_size = float(profile.cell_size)

	var macro_w: int = profile.width if profile != null else w
	var macro_h: int = profile.height if profile != null else h

	# Si es un chunk, verificar si contiene o colinda con agua (evitar crear mallas vacías en tierra seca)
	if is_chunk:
		var has_water_near := false
		var check_rect := Rect2i(origin - Vector2i(2, 2), Vector2i(w + 5, h + 5))
		for p in hydro.water_cells.keys():
			if check_rect.has_point(p):
				has_water_near = true
				break
		if not has_water_near:
			return null

	var surf := _WaterSurfaceDataScript.new()

	var col_shallow: Color = Color(0.20, 0.55, 0.70, 1.0)
	var col_deep: Color    = Color(0.05, 0.25, 0.45, 1.0)
	if profile != null:
		if "water_color_shallow" in profile:
			col_shallow = profile.water_color_shallow
		if "water_color_lake" in profile:
			col_deep = profile.water_color_lake

	# -------------------------------------------------------------------------
	# PASO 1: Cota base geometrica para celdas secas (water_datum independiente)
	# -------------------------------------------------------------------------
	var min_water_h: float = INF
	var w_cells: Dictionary = hydro.water_cells.duplicate()
	for pos in w_cells.keys():
		var cell_info = w_cells.get(pos, null)
		if cell_info is Dictionary:
			var wh: float = float(cell_info.get("water_height", 0.0))
			if wh < min_water_h:
				min_water_h = wh

	var water_datum: float = 0.0
	if min_water_h != INF:
		water_datum = min_water_h - 1.0
	elif profile != null and "base_height" in profile:
		water_datum = float(profile.base_height) - 1.0

	# -------------------------------------------------------------------------
	# CONSTRUCCIÓN CANÓNICA UNIFICADA: Quads planos por celda + Cascadas (Waterfalls)
	# Aplicado idénticamente a mundos globales (laboratorio, gameplay) y chunks en streaming.
	# Elimina cualquier divergencia geométrica entre laboratorio y juego.
	# -------------------------------------------------------------------------
	var wf_thresh: float = float(profile.waterfall_height_threshold) if profile != null and "waterfall_height_threshold" in profile else 0.10
	var base_pen: float = (float(profile.waterfall_base_penetration) if profile != null and "waterfall_base_penetration" in profile else 0.05) * cell_size
	var wf_off: float = (float(profile.waterfall_lip_offset) if profile != null and "waterfall_lip_offset" in profile else 0.04) * cell_size
	var wf_col := col_shallow
	wf_col.a = 1.0

	for y in range(h):
		for x in range(w):
			var pos2i := origin + Vector2i(x, y)
			var is_water: bool = hydro.water_cells.has(pos2i)

			if not is_water:
				continue

			var cdata_val = hydro.water_cells.get(pos2i, null)
			if not (cdata_val is Dictionary):
				continue
			var cdata: Dictionary = cdata_val
			var water_y: float = float(cdata.get("water_height", water_datum))
			var flow: Vector2 = Vector2(cdata.get("flow_dir", Vector2.ZERO))
			var depth: float = float(cdata.get("depth", 0.5))

			var x0: float = float(x) * cell_size
			var x1: float = float(x + 1) * cell_size
			var z0: float = float(y) * cell_size
			var z1: float = float(y + 1) * cell_size

			var p0 := Vector3(x0, water_y, z0)
			var p1 := Vector3(x1, water_y, z0)
			var p2 := Vector3(x0, water_y, z1)
			var p3 := Vector3(x1, water_y, z1)

			var base_idx: int = surf.vertices.size()
			for corner in range(4):
				var c_pos: Vector2i
				var c_v: Vector3
				if corner == 0:
					c_pos = pos2i
					c_v = p0
				elif corner == 1:
					c_pos = pos2i + Vector2i(1, 0)
					c_v = p1
				elif corner == 2:
					c_pos = pos2i + Vector2i(0, 1)
					c_v = p2
				else:
					c_pos = pos2i + Vector2i(1, 1)
					c_v = p3

				var uv := Vector2(float(c_pos.x) / float(macro_w), float(c_pos.y) / float(macro_h))
				var corner_sdf: float
				if hydro.water_cells.has(c_pos):
					var has_dry := false
					for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if not hydro.water_cells.has(c_pos + off):
							has_dry = true
							break
					corner_sdf = 0.65 if has_dry else 1.0
				else:
					# Vértice limítrofe hacia tierra firme: 0.60 para visibilidad sin corte en shader
					corner_sdf = 0.60

				var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
				col.a = corner_sdf
				surf.add_vertex(c_v, Vector3.UP, uv, flow, col)

			surf.add_triangle(base_idx + 0, base_idx + 1, base_idx + 2)
			surf.add_triangle(base_idx + 1, base_idx + 3, base_idx + 2)

			# -----------------------------------------------------------------
			# GENERACIÓN DE CASCADAS (WATERFALL QUADS)
			# Si un vecino de agua cardinal tiene una cota estrictamente inferior
			# (water_y - n_wh > wf_thresh), emitir exactamente un quad vertical
			# -----------------------------------------------------------------
			var pos_w := pos2i + Vector2i(-1, 0)
			var pos_e := pos2i + Vector2i(1, 0)
			var pos_n := pos2i + Vector2i(0, -1)
			var pos_s := pos2i + Vector2i(0, 1)

			var has_wf_w := false
			var has_wf_e := false
			var has_wf_n := false
			var has_wf_s := false
			var n_wh_w: float = water_y
			var n_wh_e: float = water_y
			var n_wh_n: float = water_y
			var n_wh_s: float = water_y

			# Identificadores de cuerpo de agua de la celda actual
			var cur_lake_id: int = int(cdata.get("lake_id", -1))
			var cur_river_id: int = int(cdata.get("river_index", -1))

			var cw_data = hydro.water_cells.get(pos_w, null)
			if cw_data is Dictionary:
				n_wh_w = float(cw_data.get("water_height", water_datum))
				var nw_lake_id: int = int(cw_data.get("lake_id", -1))
				var nw_river_id: int = int(cw_data.get("river_index", -1))
				var is_same_lake: bool = (cur_lake_id != -1 and nw_lake_id != -1 and cur_lake_id == nw_lake_id)
				var is_same_flat_river: bool = (cur_river_id != -1 and nw_river_id != -1 and cur_river_id == nw_river_id and absf(water_y - n_wh_w) <= wf_thresh)
				if not is_same_lake and not is_same_flat_river:
					has_wf_w = (water_y - n_wh_w > wf_thresh)

			var ce_data = hydro.water_cells.get(pos_e, null)
			if ce_data is Dictionary:
				n_wh_e = float(ce_data.get("water_height", water_datum))
				var ne_lake_id: int = int(ce_data.get("lake_id", -1))
				var ne_river_id: int = int(ce_data.get("river_index", -1))
				var is_same_lake: bool = (cur_lake_id != -1 and ne_lake_id != -1 and cur_lake_id == ne_lake_id)
				var is_same_flat_river: bool = (cur_river_id != -1 and ne_river_id != -1 and cur_river_id == ne_river_id and absf(water_y - n_wh_e) <= wf_thresh)
				if not is_same_lake and not is_same_flat_river:
					has_wf_e = (water_y - n_wh_e > wf_thresh)

			var cn_data = hydro.water_cells.get(pos_n, null)
			if cn_data is Dictionary:
				n_wh_n = float(cn_data.get("water_height", water_datum))
				var nn_lake_id: int = int(cn_data.get("lake_id", -1))
				var nn_river_id: int = int(cn_data.get("river_index", -1))
				var is_same_lake: bool = (cur_lake_id != -1 and nn_lake_id != -1 and cur_lake_id == nn_lake_id)
				var is_same_flat_river: bool = (cur_river_id != -1 and nn_river_id != -1 and cur_river_id == nn_river_id and absf(water_y - n_wh_n) <= wf_thresh)
				if not is_same_lake and not is_same_flat_river:
					has_wf_n = (water_y - n_wh_n > wf_thresh)

			var cs_data = hydro.water_cells.get(pos_s, null)
			if cs_data is Dictionary:
				n_wh_s = float(cs_data.get("water_height", water_datum))
				var ns_lake_id: int = int(cs_data.get("lake_id", -1))
				var ns_river_id: int = int(cs_data.get("river_index", -1))
				var is_same_lake: bool = (cur_lake_id != -1 and ns_lake_id != -1 and cur_lake_id == ns_lake_id)
				var is_same_flat_river: bool = (cur_river_id != -1 and ns_river_id != -1 and cur_river_id == ns_river_id and absf(water_y - n_wh_s) <= wf_thresh)
				if not is_same_lake and not is_same_flat_river:
					has_wf_s = (water_y - n_wh_s > wf_thresh)

			# Vecino Oeste (-X)
			if has_wf_w:
				var h_hi: float = water_y
				var h_lo: float = n_wh_w - base_pen
				var x_wf: float = x0 - wf_off
				var zw0: float = (z0 - wf_off) if has_wf_n else z0
				var zw1: float = (z1 + wf_off) if has_wf_s else z1
				var idx := surf.vertices.size()
				surf.add_vertex(Vector3(x_wf, h_hi, zw1), Vector3.LEFT, Vector2(0.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_hi, zw0), Vector3.LEFT, Vector2(1.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_lo, zw1), Vector3.LEFT, Vector2(0.0, 1.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_lo, zw0), Vector3.LEFT, Vector2(1.0, 1.0), flow, wf_col)
				surf.add_triangle(idx + 0, idx + 1, idx + 2)
				surf.add_triangle(idx + 1, idx + 3, idx + 2)

			# Vecino Este (+X)
			if has_wf_e:
				var h_hi: float = water_y
				var h_lo: float = n_wh_e - base_pen
				var x_wf: float = x1 + wf_off
				var ze0: float = (z0 - wf_off) if has_wf_n else z0
				var ze1: float = (z1 + wf_off) if has_wf_s else z1
				var idx := surf.vertices.size()
				surf.add_vertex(Vector3(x_wf, h_hi, ze0), Vector3.RIGHT, Vector2(0.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_hi, ze1), Vector3.RIGHT, Vector2(1.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_lo, ze0), Vector3.RIGHT, Vector2(0.0, 1.0), flow, wf_col)
				surf.add_vertex(Vector3(x_wf, h_lo, ze1), Vector3.RIGHT, Vector2(1.0, 1.0), flow, wf_col)
				surf.add_triangle(idx + 0, idx + 1, idx + 2)
				surf.add_triangle(idx + 1, idx + 3, idx + 2)

			# Vecino Norte (-Z)
			if has_wf_n:
				var h_hi: float = water_y
				var h_lo: float = n_wh_n - base_pen
				var z_wf: float = z0 - wf_off
				var xn0: float = (x0 - wf_off) if has_wf_w else x0
				var xn1: float = (x1 + wf_off) if has_wf_e else x1
				var idx := surf.vertices.size()
				surf.add_vertex(Vector3(xn0, h_hi, z_wf), Vector3.FORWARD, Vector2(0.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(xn1, h_hi, z_wf), Vector3.FORWARD, Vector2(1.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(xn0, h_lo, z_wf), Vector3.FORWARD, Vector2(0.0, 1.0), flow, wf_col)
				surf.add_vertex(Vector3(xn1, h_lo, z_wf), Vector3.FORWARD, Vector2(1.0, 1.0), flow, wf_col)
				surf.add_triangle(idx + 0, idx + 1, idx + 2)
				surf.add_triangle(idx + 1, idx + 3, idx + 2)

			# Vecino Sur (+Z)
			if has_wf_s:
				var h_hi: float = water_y
				var h_lo: float = n_wh_s - base_pen
				var z_wf: float = z1 + wf_off
				var xs0: float = (x0 - wf_off) if has_wf_w else x0
				var xs1: float = (x1 + wf_off) if has_wf_e else x1
				var idx := surf.vertices.size()
				surf.add_vertex(Vector3(xs1, h_hi, z_wf), Vector3.BACK, Vector2(0.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(xs0, h_hi, z_wf), Vector3.BACK, Vector2(1.0, 0.0), flow, wf_col)
				surf.add_vertex(Vector3(xs1, h_lo, z_wf), Vector3.BACK, Vector2(0.0, 1.0), flow, wf_col)
				surf.add_vertex(Vector3(xs0, h_lo, z_wf), Vector3.BACK, Vector2(1.0, 1.0), flow, wf_col)
				surf.add_triangle(idx + 0, idx + 1, idx + 2)
				surf.add_triangle(idx + 1, idx + 3, idx + 2)

	return surf
