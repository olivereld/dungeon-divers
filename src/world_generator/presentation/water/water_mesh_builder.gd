class_name WaterMeshBuilder
extends RefCounted

## Builder canonico y unificado de mallas de agua global (BLOQUE — WaterMesh Global).
## Genera un unico ArrayMesh global que comparte el contrato espacial 1:1 con TerrainMeshBuilder.
##
## Principios:
## 1. Contrato espacial 1:1 con TerrainMesh:
##    - WaterMesh.grid == TerrainMesh.grid
##    - WaterMesh.extent == TerrainMesh.extent (X in [0, W-1], Z in [0, H-1])
##    - WaterMesh.resolution == TerrainMesh.resolution (W * H vertices)
##    - WaterMesh.indices == TerrainMesh.indices ((W-1) * (H-1) * 2 triangles)
## 2. Separacion de responsabilidades:
##    - ShorelineResolver: todo el calculo del SDF (curvas, distancias, signo)
##    - WaterMeshBuilder:  solo geometria y empaquetado en ArrayMesh
##    - water_flow.gdshader: 4 capas independientes (silueta / depth / noise / foam)
## 3. Altura de celdas secas (Respaldo Geometrico sin invencion hidraulica):
##    - Water cells: vertex.y = water_cells[pos]["water_height"] (congelada, sin modificar ni suavizar).
##    - Dry cells: water_datum base independiente (nunca terreno ni datos inventados).
## 4. Invarianza hidraulica estricta:
##    - hydro.water_cells permanece 100% inmutable durante toda la construccion.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _WaterTopologyScript    = preload("res://src/world_generator/presentation/water/water_topology.gd")
const _ShorelineResolverScript = preload("res://src/world_generator/presentation/water/shoreline_resolver.gd")

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

	var grid_w: int = w + 1 if is_chunk else w
	var grid_h: int = h + 1 if is_chunk else h
	var quad_w: int = w if is_chunk else w - 1
	var quad_h: int = h if is_chunk else h - 1

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
	# PASO 2: SDF de orilla — delegado a ShorelineResolver (SRP)
	# -------------------------------------------------------------------------
	# -------------------------------------------------------------------------
	# PASO 2: SDF de orilla — delegado a ShorelineResolver (SRP)
	# -------------------------------------------------------------------------
	var shore_off: float = float(profile.shoreline_offset) if (profile != null and "shoreline_offset" in profile) else -0.3
	var shore_sdf: PackedFloat32Array = hydro.shoreline_sdf
	if not is_chunk:
		if shore_sdf.is_empty() or shore_sdf.size() != macro_w * macro_h:
			var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, macro_w, macro_h)
			shore_sdf = _ShorelineResolverScript.compute(
				hydro.water_cells, topo, macro_w, macro_h, result.master_seed,
				_ShorelineResolverScript.DEFAULT_ORGANIC_AMPLITUDE, shore_off
			)
			hydro.shoreline_sdf = shore_sdf

	# -------------------------------------------------------------------------
	# PASO 2.5: Extender y suavizar la altura hacia celdas secas (transición 3+ celdas)
	# -------------------------------------------------------------------------
	var extended_heights: PackedFloat32Array = hydro.extended_water_heights
	if not is_chunk:
		if extended_heights.is_empty() or extended_heights.size() != macro_w * macro_h:
			extended_heights = _compute_extended_water_heights(
				hydro.water_cells, macro_w, macro_h, water_datum, 4
			)
			hydro.extended_water_heights = extended_heights

	if is_chunk:
		# En streaming de chunks, construir quads horizontales desacoplados por celda (100% planos).
		# Elimina las rampas inclinadas entre niveles y previene los picos triangulares en cascadas y desniveles.
		var step_h: float = float(profile.elevation_step_height) if profile != null and "elevation_step_height" in profile else 2.0
		for y in range(h):
			for x in range(w):
				var pos2i := origin + Vector2i(x, y)
				var is_water: bool = hydro.water_cells.has(pos2i)

				var water_y: float = water_datum
				var flow: Vector2 = Vector2.ZERO
				var depth: float = 0.5

				if not is_water:
					continue

				var cdata_val = hydro.water_cells.get(pos2i, null)
				if not (cdata_val is Dictionary):
					continue
				var cdata: Dictionary = cdata_val
				water_y = float(cdata.get("water_height", water_datum))
				flow = Vector2(cdata.get("flow_dir", Vector2.ZERO))
				depth = float(cdata.get("depth", 0.5))

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
						# Esta esquina pertenece a un vertice adyacente seco en la frontera
						# de un quad de agua. Fijar en 0.60 para que la orilla permanezca
						# visible y continua sobre el cauce sin ser descartada por el shader.
						corner_sdf = 0.60

					var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
					col.a = corner_sdf
					surf.add_vertex(c_v, Vector3.UP, uv, flow, col)

				surf.add_triangle(base_idx + 0, base_idx + 1, base_idx + 2)
				surf.add_triangle(base_idx + 1, base_idx + 3, base_idx + 2)

				# -------------------------------------------------------------
				# GENERACIÓN DE CASCADAS (WATERFALL QUADS)
				# Si la celda es agua, evaluar sus 4 vecinos cardinales.
				# Si un vecino es celda de agua con cota estrictamente inferior
				# (water_y - n_wh > WATERFALL_MIN_DROP), emitir exactamente un quad
				# vertical desplazado hacia la celda inferior y con penetración basal.
				# -------------------------------------------------------------
				if is_water:
					var wf_thresh: float = float(profile.waterfall_height_threshold) if profile != null and "waterfall_height_threshold" in profile else 0.10
					var base_pen: float = (float(profile.waterfall_base_penetration) if profile != null and "waterfall_base_penetration" in profile else 0.05) * cell_size
					var wf_off: float = (float(profile.waterfall_lip_offset) if profile != null and "waterfall_lip_offset" in profile else 0.04) * cell_size
					var wf_col := col_shallow
					wf_col.a = 1.0

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

					# Cascadas (Waterfall Quads): se emite en cualquier cara cardinal donde el vecino
					# de agua tenga una cota estrictamente inferior (desnivel > 0.10m).
					# Esto garantiza que todos los bordes del escalón hidráulico estén sellados
					# sin huecos frontales ni laterales.
					var cw_data = hydro.water_cells.get(pos_w, null)
					if cw_data is Dictionary:
						n_wh_w = float(cw_data.get("water_height", water_datum))
						has_wf_w = (water_y - n_wh_w > wf_thresh)

					var ce_data = hydro.water_cells.get(pos_e, null)
					if ce_data is Dictionary:
						n_wh_e = float(ce_data.get("water_height", water_datum))
						has_wf_e = (water_y - n_wh_e > wf_thresh)

					var cn_data = hydro.water_cells.get(pos_n, null)
					if cn_data is Dictionary:
						n_wh_n = float(cn_data.get("water_height", water_datum))
						has_wf_n = (water_y - n_wh_n > wf_thresh)

					var cs_data = hydro.water_cells.get(pos_s, null)
					if cs_data is Dictionary:
						n_wh_s = float(cs_data.get("water_height", water_datum))
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

	# -------------------------------------------------------------------------
	# PASO 3: Generar grilla de vertices (1:1 con TerrainMeshBuilder)
	# -------------------------------------------------------------------------
	for y in range(grid_h):
		for x in range(grid_w):
			var pos2i := origin + Vector2i(x, y)
			var is_water: bool = hydro.water_cells.has(pos2i)
			var water_y: float = water_datum
			var flow: Vector2 = Vector2.ZERO
			var depth: float = 0.0
			var sdf_val: float = 0.0

			if is_chunk:
				if is_water:
					var cdata: Dictionary = hydro.water_cells[pos2i]
					water_y = float(cdata.get("water_height", water_datum))
					flow = Vector2(cdata.get("flow_dir", Vector2.ZERO))
					depth = float(cdata.get("depth", 0.5))
					var has_dry := false
					for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if not hydro.water_cells.has(pos2i + off):
							has_dry = true
							break
					sdf_val = 0.65 if has_dry else 1.0
				else:
					var min_d_sq: float = 999.0
					var nearest_h: float = water_datum
					for dy in range(-3, 4):
						for dx in range(-3, 4):
							var np := pos2i + Vector2i(dx, dy)
							if hydro.water_cells.has(np):
								var d_sq := float(dx * dx + dy * dy)
								if d_sq < min_d_sq:
									min_d_sq = d_sq
									nearest_h = float(hydro.water_cells[np].get("water_height", water_datum))
					if min_d_sq < 900.0:
						water_y = nearest_h
						var dist := sqrt(min_d_sq)
						var signed_dist := -(dist - 0.5)
						sdf_val = clampf(0.5 + signed_dist / 6.0, 0.0, 0.49)
					else:
						water_y = water_datum
						sdf_val = 0.0
			else:
				if not extended_heights.is_empty() and y < h and x < w:
					water_y = extended_heights[y * w + x]
				if is_water:
					var cdata: Dictionary = hydro.water_cells[pos2i]
					water_y = float(cdata.get("water_height", water_datum))
					flow  = Vector2(cdata.get("flow_dir", Vector2.ZERO))
					depth = float(cdata.get("depth", 0.5))
				if not shore_sdf.is_empty() and y < h and x < w:
					sdf_val = shore_sdf[y * w + x]
				elif is_water:
					sdf_val = 1.0

			var v_pos := Vector3(float(x) * cell_size, water_y, float(y) * cell_size)
			var uv    := Vector2(float(pos2i.x) / float(macro_w), float(pos2i.y) / float(macro_h))
			var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
			col.a = sdf_val

			surf.add_vertex(v_pos, Vector3.UP, uv, flow, col)

	# -------------------------------------------------------------------------
	# PASO 4: Triangulacion (quad_w * quad_h quads, 1:1 con TerrainMeshBuilder)
	# -------------------------------------------------------------------------
	for y in range(quad_h):
		for x in range(quad_w):
			var i0 := y * grid_w + x
			var i1 := y * grid_w + (x + 1)
			var i2 := (y + 1) * grid_w + x
			var i3 := (y + 1) * grid_w + (x + 1)
			surf.add_triangle(i0, i1, i2)
			surf.add_triangle(i1, i3, i2)

	return surf

## Extiende y suaviza la altura de la lámina de agua hacia las celdas secas circundantes
## (al menos 3 a 4 celdas hacia tierra firme) para evitar cortes abruptos y garantizar
## una transición geométrica continua y plana bajo las riberas del terreno.
static func _compute_extended_water_heights(
		water_cells: Dictionary,
		w: int,
		h: int,
		water_datum: float,
		ext_radius: int = 4
	) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	heights.fill(water_datum)

	if water_cells.is_empty():
		return heights

	var resolved := {}

	# 1. Celdas de agua fijas (inmutables, cota canónica exacta)
	for pos in water_cells.keys():
		if pos.x >= 0 and pos.x < w and pos.y >= 0 and pos.y < h:
			var wh: float = float(water_cells[pos].get("water_height", water_datum))
			heights[pos.y * w + pos.x] = wh
			resolved[pos] = true

	var d8: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	# 2. Identificar la frontera de celdas secas adyacentes a cuerpos de agua
	var current_frontier: Array[Vector2i] = []
	var frontier_set := {}
	for pos in water_cells.keys():
		if pos.x >= 0 and pos.x < w and pos.y >= 0 and pos.y < h:
			for off in d8:
				var np: Vector2i = pos + off
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					if not resolved.has(np) and not frontier_set.has(np):
						frontier_set[np] = true
						current_frontier.append(np)

	# 3. Propagar la altura del agua hacia las celdas secas capa por capa (3+ celdas)
	for step in range(ext_radius):
		if current_frontier.is_empty():
			break

		var next_frontier: Array[Vector2i] = []
		var next_set := {}
		var step_heights: Dictionary = {}

		for p in current_frontier:
			var sum_h: float = 0.0
			var count: int = 0
			for off in d8:
				var np: Vector2i = p + off
				if resolved.has(np):
					sum_h += heights[np.y * w + np.x]
					count += 1
			if count > 0:
				step_heights[p] = sum_h / float(count)
			else:
				step_heights[p] = water_datum

		for p in current_frontier:
			heights[p.y * w + p.x] = float(step_heights[p])
			resolved[p] = true

			for off in d8:
				var np: Vector2i = p + off
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					if not resolved.has(np) and not next_set.has(np):
						next_set[np] = true
						next_frontier.append(np)

		current_frontier = next_frontier

	# 4. Transición suave hacia water_datum para el borde exterior
	var taper_steps: int = 2
	for t in range(taper_steps):
		if current_frontier.is_empty():
			break
		var taper_factor: float = 1.0 - float(t + 1) / float(taper_steps + 1)
		var next_frontier: Array[Vector2i] = []
		var next_set := {}

		for p in current_frontier:
			var sum_h: float = 0.0
			var count: int = 0
			for off in d8:
				var np: Vector2i = p + off
				if resolved.has(np):
					sum_h += heights[np.y * w + np.x]
					count += 1
			var avg_h: float = (sum_h / float(count)) if count > 0 else water_datum
			heights[p.y * w + p.x] = lerpf(water_datum, avg_h, taper_factor)
			resolved[p] = true

			for off in d8:
				var np: Vector2i = p + off
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					if not resolved.has(np) and not next_set.has(np):
						next_set[np] = true
						next_frontier.append(np)

		current_frontier = next_frontier

	return heights
