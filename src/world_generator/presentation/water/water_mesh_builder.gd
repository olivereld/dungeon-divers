class_name WaterMeshBuilder
extends RefCounted

## Builder canónico y unificado de mallas de agua global (BLOQUE — WaterMesh Global).
## Genera un único ArrayMesh global que comparte el contrato espacial 1:1 con TerrainMeshBuilder.
##
## Principios:
## 1. Contrato espacial 1:1 con TerrainMesh:
##    - WaterMesh.grid == TerrainMesh.grid
##    - WaterMesh.extent == TerrainMesh.extent (X in [0, W-1], Z in [0, H-1])
##    - WaterMesh.resolution == TerrainMesh.resolution (W * H vertices)
##    - WaterMesh.indices == TerrainMesh.indices ((W-1) * (H-1) * 2 triangles)
## 2. Separación de Geometría y Estado Hidráulico:
##    - La geometría existe para toda la grilla del mundo (W * H).
##    - water_cells actúa exclusivamente como máscara hidráulica (COLOR.a = 1.0 agua, 0.0 seco).
## 3. Altura de celdas secas (Respaldo Geométrico sin invención hidráulica):
##    - Water cells: vertex.y = water_cells[pos]["water_height"].
##    - Dry cells: NO se inventa water_height ni se alteran water_cells.
##      Adopta una cota geométrica de respaldo estructural (datum global y extensión de orilla plana).
## 4. Independencia del TerrainMesh:
##    - No copia cell.height ni calcula offsets sobre el terreno.
##    - Coincidencia puramente espacial, nunca hidráulica.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")

## API canónica de entrada para construir la malla de agua global
static func build_mesh(result: WorldResult, profile = null) -> ArrayMesh:
	var surf: WaterSurfaceData = build_water_surface(result, profile)
	if surf == null:
		return null
	return surf.to_array_mesh()

## Analiza y retorna la topología hidráulica formal de water_cells (BLOQUE 6)
static func build_topology(result: WorldResult) -> WaterTopology:
	if result == null or result.hydrology == null:
		return null
	return _WaterTopologyScript.analyze(result.hydrology.water_cells, result.dimensions.x, result.dimensions.y)

## Construye la superficie global del agua cubriendo la grilla completa del mundo (1:1 con TerrainMesh)
static func build_water_surface(result: WorldResult, profile = null) -> WaterSurfaceData:
	if result == null or result.hydrology == null:
		return null

	var hydro: HydrologyResult = result.hydrology
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	if w <= 1 or h <= 1:
		return null

	# Si el mundo no tiene ninguna celda de agua definida, no se instancia malla
	if hydro.water_cells.is_empty():
		return null

	var surf := _WaterSurfaceDataScript.new()

	var col_shallow: Color = Color(0.20, 0.55, 0.70, 1.0)
	var col_deep: Color = Color(0.05, 0.25, 0.45, 1.0)
	if profile != null:
		if "water_color_shallow" in profile:
			col_shallow = profile.water_color_shallow
		if "water_color_lake" in profile:
			col_deep = profile.water_color_lake

	# 1. Determinar cota geométrica de respaldo estructural (datum)
	# Extraída puramente como cota base de referencia para celdas secas sin contacto con agua
	var datum_y: float = 0.0
	var min_water_h: float = INF
	for pos in hydro.water_cells.keys():
		var wh: float = float(hydro.water_cells[pos].get("water_height", 0.0))
		if wh < min_water_h:
			min_water_h = wh

	if min_water_h != INF:
		datum_y = min_water_h - 1.0
	elif profile != null and "base_height" in profile:
		datum_y = float(profile.base_height) - 1.0

	# 2. Generar grilla de vértices global: W * H vértices (1:1 con TerrainMeshBuilder)
	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var is_water: bool = hydro.water_cells.has(pos2i)

			var water_y: float = datum_y
			var mask: float = 0.0
			var flow: Vector2 = Vector2.ZERO
			var depth: float = 0.0

			if is_water:
				var cdata: Dictionary = hydro.water_cells[pos2i]
				water_y = float(cdata.get("water_height", datum_y))
				mask = 1.0
				flow = Vector2(cdata.get("flow_dir", Vector2.ZERO))
				depth = float(cdata.get("depth", 0.5))
			else:
				# Celda seca: extensión plana de orilla en frontera inmediata si toca agua
				var neighbor_water_h: float = 0.0
				var neighbor_count: int = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var npos := Vector2i(x + dx, y + dy)
						if hydro.water_cells.has(npos):
							neighbor_water_h += float(hydro.water_cells[npos].get("water_height", datum_y))
							neighbor_count += 1
				if neighbor_count > 0:
					water_y = neighbor_water_h / float(neighbor_count)
				else:
					water_y = datum_y

			var v_pos := Vector3(float(x), water_y, float(y))
			var uv := Vector2(float(x) / float(w), float(y) / float(h))
			var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
			col.a = mask

			surf.add_vertex(v_pos, Vector3.UP, uv, flow, col)

	# 3. Triangulación global: (W - 1) * (H - 1) quads (1:1 con TerrainMeshBuilder)
	for y in range(h - 1):
		for x in range(w - 1):
			var i0 := y * w + x
			var i1 := y * w + (x + 1)
			var i2 := (y + 1) * w + x
			var i3 := (y + 1) * w + (x + 1)

			# Triángulo 1 (CCW para normal +Y)
			surf.add_triangle(i0, i1, i2)
			# Triángulo 2 (CCW para normal +Y)
			surf.add_triangle(i1, i3, i2)

	return surf
