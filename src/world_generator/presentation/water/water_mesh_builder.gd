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
##    - Water cells: vertex.y = water_cells[pos]["water_height"].
##    - Dry cells: extension armonica de Laplace (datum suave, nunca dato inventado).
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
	# PASO 1: Campo de cotas de agua — Dirichlet + BFS + Laplace
	# -------------------------------------------------------------------------
	var height_grid: PackedFloat32Array = PackedFloat32Array()
	height_grid.resize(w * h)
	var is_water_grid: PackedByteArray = PackedByteArray()
	is_water_grid.resize(w * h)

	var bfs_queue: Array[Vector2i] = []
	for pos in hydro.water_cells.keys():
		var wh: float = float(hydro.water_cells[pos].get("water_height", 0.0))
		var idx: int = pos.y * w + pos.x
		height_grid[idx] = wh
		is_water_grid[idx] = 1
		bfs_queue.append(pos)

	# Propagacion BFS hacia celdas secas
	var head: int = 0
	while head < bfs_queue.size():
		var curr: Vector2i = bfs_queue[head]
		head += 1
		var curr_h: float = height_grid[curr.y * w + curr.x]
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = curr.x + offset.x
			var ny: int = curr.y + offset.y
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var nidx: int = ny * w + nx
				if is_water_grid[nidx] == 0 and height_grid[nidx] == 0.0:
					height_grid[nidx] = curr_h
					bfs_queue.append(Vector2i(nx, ny))

	# -------------------------------------------------------------------------
	# PASO 2: Suavizado visual de rios (sin alterar datos hidraulicos)
	# -------------------------------------------------------------------------
	var orig_water_h: PackedFloat32Array = height_grid.duplicate()
	var next_h: PackedFloat32Array = height_grid.duplicate()

	for _it in range(3):
		for y in range(h):
			for x in range(w):
				var idx: int = y * w + x
				var pos := Vector2i(x, y)
				if is_water_grid[idx] == 1:
					var cdata: Dictionary = hydro.water_cells[pos]
					if cdata.get("type") == "lake":
						next_h[idx] = orig_water_h[idx]
						continue
					var sum_h: float = 0.0
					var count: float = 0.0
					var min_local: float = orig_water_h[idx]
					var max_local: float = orig_water_h[idx]
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var npos := Vector2i(x + dx, y + dy)
							if hydro.water_cells.has(npos):
								var nidx: int = npos.y * w + npos.x
								var n_orig: float = orig_water_h[nidx]
								min_local = minf(min_local, n_orig)
								max_local = maxf(max_local, n_orig)
								var weight: float = 2.0 if (dx == 0 and dy == 0) else (1.0 if (dx == 0 or dy == 0) else 0.707)
								sum_h += height_grid[nidx] * weight
								count += weight
					if count > 0.0:
						next_h[idx] = clampf(sum_h / count, min_local, max_local)
		height_grid = next_h.duplicate()

	# -------------------------------------------------------------------------
	# PASO 3: Relajacion armonica de Laplace en celdas secas
	# -------------------------------------------------------------------------
	for _it in range(10):
		for y in range(h):
			var row_idx: int = y * w
			for x in range(w):
				var idx: int = row_idx + x
				if is_water_grid[idx] == 1:
					continue
				var sum_h: float = 0.0
				var count: int = 0
				if x > 0:          sum_h += height_grid[idx - 1]; count += 1
				if x < w - 1:      sum_h += height_grid[idx + 1]; count += 1
				if y > 0:          sum_h += height_grid[idx - w]; count += 1
				if y < h - 1:      sum_h += height_grid[idx + w]; count += 1
				if count > 0:
					var relaxed: float = sum_h / float(count)
					if result.cells.has(Vector2i(x, y)):
						height_grid[idx] = minf(relaxed, result.cells[Vector2i(x, y)].height - 0.08)
					else:
						height_grid[idx] = relaxed

	# -------------------------------------------------------------------------
	# PASO 4: SDF de orilla — delegado a ShorelineResolver (SRP)
	# -------------------------------------------------------------------------
	var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, w, h)
	var shore_sdf: PackedFloat32Array = _ShorelineResolverScript.compute(hydro.water_cells, topo, w, h, result.master_seed)

	# -------------------------------------------------------------------------
	# PASO 5: Generar grilla de vertices global W*H (1:1 con TerrainMeshBuilder)
	# -------------------------------------------------------------------------
	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var is_water: bool = hydro.water_cells.has(pos2i)
			var water_y: float = height_grid[y * w + x]
			var flow: Vector2 = Vector2.ZERO
			var depth: float = 0.0

			if is_water:
				var cdata: Dictionary = hydro.water_cells[pos2i]
				flow  = Vector2(cdata.get("flow_dir", Vector2.ZERO))
				depth = float(cdata.get("depth", 0.5))

			var v_pos := Vector3(float(x), water_y, float(y))
			var uv    := Vector2(float(x) / float(w), float(y) / float(h))
			var col: Color = col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))
			col.a = shore_sdf[y * w + x]   # SDF empaquetado en COLOR.a

			surf.add_vertex(v_pos, Vector3.UP, uv, flow, col)

	# -------------------------------------------------------------------------
	# PASO 6: Triangulacion global (W-1)*(H-1) quads (1:1 con TerrainMeshBuilder)
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
