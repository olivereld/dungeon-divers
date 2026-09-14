class_name WaterMeshBuilder
extends RefCounted

## Builder canónico y unificado de mallas de agua (BLOQUE 5).
## Genera un único ArrayMesh global basado exclusivamente en HydrologyResult.water_cells.
##
## Principios:
## 1. Autoridad espacial única: water_cells es la única fuente de verdad de agua.
## 2. Continuidad geométrica: no discrimina entre río o lago; trata todo cuerpo
##    de agua como un continuo hidrológico unificado.
## 3. Celda de agua -> geometría; celda seca -> ninguna geometría.
## 4. Evita geometría duplicada entre celdas compartidas mediante caché de vértices indexados.
## 5. La resolución de water_height se mantiene modular y desacoplada (BLOQUE 7).
## 6. Agua debajo del terreno e independencia física (BLOQUE 8):
##    El WaterMesh se genera incondicionalmente para toda water_cell sin consultar ni
##    alterar WorldCell.height. La visibilidad surge de forma natural por oclusión de
##    profundidad GPU: si cell.height > water_height, el terreno cubre el agua; si el
##    tallado deja cell.height < water_height, el agua queda expuesta.
##    depth es estrictamente hidráulico (water_height - bed_height). Sin offsets artificiales.
## 7. Orillas como consecuencia de la frontera W/D (BLOQUE 9):
##    La orilla no es una geometría adicional (no BankMesh, no LakeBankMesh, no RiverBankMesh).
##    Es la consecuencia topológica directa del límite entre water_cells y celdas secas (dry):
##    - water -> water: interior, el agua fluye continuamente sin caras internas ni bordes.
##    - water -> dry: frontera de agua (shoreline).
##    - water -> exterior: frontera de agua (límite exterior del mundo).
##    La superficie del agua termina exactamente en esa frontera W/D.
##    La geometría subyacente y circundante de TerrainMesh proporciona visualmente la orilla.

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

## Construye la estructura de datos de superficie WaterSurfaceData
static func build_water_surface(result: WorldResult, profile = null) -> WaterSurfaceData:
	if result == null or result.hydrology == null:
		return null

	var hydro: HydrologyResult = result.hydrology
	if hydro.water_cells.is_empty():
		return null

	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	var cell_size: float = 1.0
	if profile != null and "cell_size" in profile and profile.cell_size > 0.0:
		cell_size = float(profile.cell_size)

	# BLOQUE 6: Topología hidráulica de conectividad y clasificación de aristas
	var topology: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, w, h)

	var surf = _WaterSurfaceDataScript.new()
	var vertex_cache: Dictionary = {}

	var col_shallow: Color = Color(0.20, 0.55, 0.70, 0.85)
	var col_deep: Color = Color(0.05, 0.25, 0.45, 0.95)
	if profile != null:
		if "water_color_shallow" in profile:
			col_shallow = profile.water_color_shallow
		if "water_color_lake" in profile:
			col_deep = profile.water_color_lake

	# Recorrer exclusivamente cada water_cell (celda con agua -> geometría; seca -> ninguna geometría)
	for pos in hydro.water_cells.keys():
		# 4 esquinas de la celda de agua pos (centrada en pos):
		# p0: esquina Noroeste (-0.5, -0.5)
		# p1: esquina Suroeste (-0.5, +0.5)
		# p2: esquina Sureste  (+0.5, +0.5)
		# p3: esquina Noreste  (+0.5, -0.5)
		var i0: int = _get_or_add_corner_vertex(surf, pos, Vector2i(-1, -1), cell_size, hydro, col_shallow, col_deep, vertex_cache)
		var i1: int = _get_or_add_corner_vertex(surf, pos, Vector2i(-1, 1), cell_size, hydro, col_shallow, col_deep, vertex_cache)
		var i2: int = _get_or_add_corner_vertex(surf, pos, Vector2i(1, 1), cell_size, hydro, col_shallow, col_deep, vertex_cache)
		var i3: int = _get_or_add_corner_vertex(surf, pos, Vector2i(1, -1), cell_size, hydro, col_shallow, col_deep, vertex_cache)

		# Triángulos en orden antihorario para normal hacia arriba (+Y)
		surf.add_triangle(i0, i1, i2)
		surf.add_triangle(i0, i2, i3)

	return surf

## Obtiene o crea un vértice indexado en la esquina de una celda, compartiéndolo con celdas vecinas
static func _get_or_add_corner_vertex(
	surf: WaterSurfaceData,
	pos: Vector2i,
	corner_sign: Vector2i,
	cell_size: float,
	hydro: HydrologyResult,
	col_shallow: Color,
	col_deep: Color,
	vertex_cache: Dictionary
) -> int:
	# Coordenada 2D continua en el mundo para esta esquina compartida
	var world_x: float = (float(pos.x) + 0.5 * float(corner_sign.x)) * cell_size
	var world_z: float = (float(pos.y) + 0.5 * float(corner_sign.y)) * cell_size

	# Llave de cuantización a 5mm para compartir vértices de celdas adyacentes
	var qx: int = int(round(world_x * 200.0))
	var qz: int = int(round(world_z * 200.0))
	var key: int = (qx << 32) | (qz & 0xFFFFFFFF)

	if vertex_cache.has(key):
		return vertex_cache[key]

	# Celdas que tocan esta esquina (hasta 4 cuadrantes)
	var sx: int = 1 if corner_sign.x > 0 else 0
	var sy: int = 1 if corner_sign.y > 0 else 0
	var ox: int = pos.x - (1 - sx)
	var oy: int = pos.y - (1 - sy)

	var touching_cells: Array[Vector2i] = [
		Vector2i(ox, oy),
		Vector2i(ox + 1, oy),
		Vector2i(ox, oy + 1),
		Vector2i(ox + 1, oy + 1)
	]

	# Resolver la cota de agua, flujo y profundidad usando las celdas de agua que tocan la esquina
	var water_y: float = _resolve_corner_water_height(pos, touching_cells, hydro)
	var flow: Vector2 = _resolve_corner_flow(pos, touching_cells, hydro)
	var depth: float = _resolve_corner_depth(pos, touching_cells, hydro)

	var v_pos := Vector3(world_x, water_y, world_z)
	var uv := Vector2(world_x * 0.1, world_z * 0.1)
	var col := col_shallow.lerp(col_deep, clampf(depth / 3.0, 0.0, 1.0))

	var idx: int = surf.add_vertex(v_pos, Vector3.UP, uv, flow, col)
	vertex_cache[key] = idx
	return idx

## Resolución de cota hidráulica de vértices (BLOQUE 7).
## Consume directamente water_cells[pos]["water_height"] = H_water como única fuente de verdad.
## Garantiza:
## - Lagos: cota horizontal exacta (promedio de cotas idénticas = spillway_height).
## - Ríos: pendiente continua y suave a lo largo del gradiente hidráulico.
## - Confluencias y desembocaduras: continuidad C0 exacta sin saltos verticales.
static func _resolve_corner_water_height(
	center_pos: Vector2i,
	touching_cells: Array[Vector2i],
	hydro: HydrologyResult
) -> float:
	var total_h: float = 0.0
	var count: int = 0

	for c in touching_cells:
		if hydro.water_cells.has(c):
			var data: Dictionary = hydro.water_cells[c]
			total_h += float(data.get("water_height", 0.0))
			count += 1

	if count > 0:
		return total_h / float(count)

	# Fallback a la celda central
	if hydro.water_cells.has(center_pos):
		return float(hydro.water_cells[center_pos].get("water_height", 0.0))
	return 0.0

static func _resolve_corner_flow(
	center_pos: Vector2i,
	touching_cells: Array[Vector2i],
	hydro: HydrologyResult
) -> Vector2:
	var flow_accum := Vector2.ZERO
	for c in touching_cells:
		if hydro.water_cells.has(c):
			var data: Dictionary = hydro.water_cells[c]
			flow_accum += Vector2(data.get("flow_dir", Vector2.ZERO))

	if flow_accum.length_squared() > 0.001:
		return flow_accum.normalized()

	if hydro.water_cells.has(center_pos):
		return Vector2(hydro.water_cells[center_pos].get("flow_dir", Vector2.ZERO))
	return Vector2.ZERO

static func _resolve_corner_depth(
	center_pos: Vector2i,
	touching_cells: Array[Vector2i],
	hydro: HydrologyResult
) -> float:
	var total_d: float = 0.0
	var count: int = 0
	for c in touching_cells:
		if hydro.water_cells.has(c):
			var data: Dictionary = hydro.water_cells[c]
			total_d += float(data.get("depth", 0.5))
			count += 1

	if count > 0:
		return total_d / float(count)

	if hydro.water_cells.has(center_pos):
		return float(hydro.water_cells[center_pos].get("depth", 0.5))
	return 0.5
