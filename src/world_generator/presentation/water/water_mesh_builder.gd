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
	for pos in hydro.water_cells.keys():
		var wh: float = float(hydro.water_cells[pos].get("water_height", 0.0))
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
	var shore_off: float = float(profile.shoreline_offset) if (profile != null and "shoreline_offset" in profile) else -0.3
	var shore_sdf: PackedFloat32Array = hydro.shoreline_sdf
	if shore_sdf.is_empty() or shore_sdf.size() != w * h:
		var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, w, h)
		shore_sdf = _ShorelineResolverScript.compute(
			hydro.water_cells, topo, w, h, result.master_seed,
			_ShorelineResolverScript.DEFAULT_ORGANIC_AMPLITUDE, shore_off
		)
		hydro.shoreline_sdf = shore_sdf

	# -------------------------------------------------------------------------
	# PASO 2.5: Extender y suavizar la altura hacia celdas secas (transición 3+ celdas)
	# -------------------------------------------------------------------------
	var extended_heights: PackedFloat32Array = _compute_extended_water_heights(
		hydro.water_cells, w, h, water_datum, 4
	)

	# -------------------------------------------------------------------------
	# PASO 3: Generar grilla de vertices global W*H (1:1 con TerrainMeshBuilder)
	# Water cells: water_height congelada (sin interpolacion ni deformacion)
	# Dry cells:   transición suave de al menos 3 celdas para evitar saltos abruptos
	# -------------------------------------------------------------------------
	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var is_water: bool = hydro.water_cells.has(pos2i)
			var water_y: float = extended_heights[y * w + x]
			var flow: Vector2 = Vector2.ZERO
			var depth: float = 0.0

			if is_water:
				var cdata: Dictionary = hydro.water_cells[pos2i]
				water_y = float(cdata.get("water_height", water_datum))
				flow  = Vector2(cdata.get("flow_dir", Vector2.ZERO))
				depth = float(cdata.get("depth", 0.5))

			var v_pos := Vector3(float(x), water_y, float(y))
			var uv    := Vector2(float(x) / float(w), float(y) / float(h))
			var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
			col.a = shore_sdf[y * w + x]   # SDF empaquetado en COLOR.a

			surf.add_vertex(v_pos, Vector3.UP, uv, flow, col)

	# -------------------------------------------------------------------------
	# PASO 4: Triangulacion global (W-1)*(H-1) quads (1:1 con TerrainMeshBuilder)
	# -------------------------------------------------------------------------
	for y in range(h - 1):
		for x in range(w - 1):
			var i0 := y * w + x
			var i1 := y * w + (x + 1)
			var i2 := (y + 1) * w + x
			var i3 := (y + 1) * w + (x + 1)
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
