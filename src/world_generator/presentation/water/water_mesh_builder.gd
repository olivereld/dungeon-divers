class_name WaterMeshBuilder
extends RefCounted

## Constructor unificado de mallas de agua para regiones hidrológicas conectadas (WaterRegion).
## Garantiza continuidad geométrica estricta, soldadura de vértices en fronteras compartidas
## (sin duplicación de vértices) y transiciones continuas de cota y vectores de flujo (UV2)
## entre ríos, deltas de transición, lagos y emisarios.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")
const _WaterRegionScript = preload("res://src/world_generator/presentation/water/water_region.gd")
const _WaterCellScript = preload("res://src/world_generator/presentation/water/water_cell.gd")

## Construye la superficie de agua completa para una colección de WaterRegions
static func build_mesh_surface(
	regions: Array,
	result: WorldResult,
	profile: WorldProfile = null
) -> RefCounted:
	var combined_surf = _WaterSurfaceDataScript.new()
	if profile == null:
		profile = WorldProfile.new()

	for reg in regions:
		var reg_surf = build_region_surface(reg, result, profile)
		if reg_surf != null and not reg_surf.vertices.is_empty():
			combined_surf.append_surface(reg_surf)

	return combined_surf

## Construye la superficie continua (WaterSurfaceData) para una única WaterRegion conectada
static func build_region_surface(
	region: RefCounted,
	result: WorldResult,
	profile: WorldProfile = null
) -> RefCounted:
	if region == null or region.cells.is_empty() or result == null:
		return _WaterSurfaceDataScript.new()

	if profile == null:
		profile = WorldProfile.new()

	var cell_size: float = profile.cell_size
	var surf = _WaterSurfaceDataScript.new()

	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	# Cache de vértices compartidos en esquinas de celda para soldadura perfecta
	# Clave 64-bit: (gx << 32) | gz
	var corner_vertex_cache: Dictionary = {}
	# Cache de vértices de orilla en aristas compartidas: (min_key << 32) | max_key
	var edge_vertex_cache: Dictionary = {}

	# Identificar quads candidatos que intersecan la región de agua
	var quads_to_process: Dictionary = {}
	for cpos in region.cells.keys():
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx: int = cpos.x + dx
				var qy: int = cpos.y + dy
				if qx >= 0 and qx < w - 1 and qy >= 0 and qy < h - 1:
					quads_to_process[Vector2i(qx, qy)] = true

	# Procesar cada quad en orden coherente
	for qpos in quads_to_process.keys():
		var c00: Vector2i = qpos
		var c10: Vector2i = qpos + Vector2i(1, 0)
		var c11: Vector2i = qpos + Vector2i(1, 1)
		var c01: Vector2i = qpos + Vector2i(0, 1)

		var in_region: bool = region.has_cell(c00) or region.has_cell(c10) or region.has_cell(c11) or region.has_cell(c01)
		if not in_region:
			continue

		# Muestrear datos de agua y distancia con signo a la superficie en cada una de las 4 esquinas
		var d00: float = _calc_corner_signed_distance(c00, region, result)
		var d10: float = _calc_corner_signed_distance(c10, region, result)
		var d11: float = _calc_corner_signed_distance(c11, region, result)
		var d01: float = _calc_corner_signed_distance(c01, region, result)

		# 1. Caso completamente seco: las 4 esquinas están fuera del agua
		if d00 > 0.0 and d10 > 0.0 and d11 > 0.0 and d01 > 0.0:
			continue

		var p00_2d := Vector2(float(c00.x), float(c00.y)) * cell_size
		var p10_2d := Vector2(float(c10.x), float(c10.y)) * cell_size
		var p11_2d := Vector2(float(c11.x), float(c11.y)) * cell_size
		var p01_2d := Vector2(float(c01.x), float(c01.y)) * cell_size

		# 2. Caso interior pleno: las 4 esquinas están completamente sumergidas
		if d00 <= 0.0 and d10 <= 0.0 and d11 <= 0.0 and d01 <= 0.0:
			var i00: int = _get_or_create_corner_vertex(surf, c00, p00_2d, region, result, profile, corner_vertex_cache)
			var i10: int = _get_or_create_corner_vertex(surf, c10, p10_2d, region, result, profile, corner_vertex_cache)
			var i11: int = _get_or_create_corner_vertex(surf, c11, p11_2d, region, result, profile, corner_vertex_cache)
			var i01: int = _get_or_create_corner_vertex(surf, c01, p01_2d, region, result, profile, corner_vertex_cache)

			_add_valid_triangle(surf, i00, i10, i11)
			_add_valid_triangle(surf, i00, i11, i01)
			continue

		# 3. Caso frontera de orilla: recortar el polígono de agua de forma continua
		_tessellate_clipped_quad(
			surf,
			[c00, c10, c11, c01],
			[p00_2d, p10_2d, p11_2d, p01_2d],
			[d00, d10, d11, d01],
			region,
			result,
			profile,
			corner_vertex_cache,
			edge_vertex_cache
		)

	return surf

## Construye un nodo 3D con la malla unificada y material configurado
static func build_water_mesh_node(
	regions: Array,
	result: WorldResult,
	profile: WorldProfile = null,
	show_wireframe: bool = false
) -> Node3D:
	var combined_surf = build_mesh_surface(regions, result, profile)
	if combined_surf == null:
		return null

	var mesh: ArrayMesh = combined_surf.to_array_mesh()
	if mesh == null:
		return null

	var root := Node3D.new()
	root.name = "WaterRoot"

	var mi := MeshInstance3D.new()
	mi.name = "UnifiedWaterSurface"
	mi.mesh = mesh
	mi.set_surface_override_material(0, _WaterMaterialScript.create_water_material(profile, true))
	root.add_child(mi)

	return root

## Muestrea la distancia con signo del terreno a la lámina de agua en la esquina (d <= 0 sumergido, d > 0 seco)
static func _calc_corner_signed_distance(
	corner: Vector2i,
	region: RefCounted,
	result: WorldResult
) -> float:
	var cell: WorldCell = result.get_cell(corner)
	var terrain_h: float = cell.height if cell != null else 0.0

	var water_data: Dictionary = _sample_water_properties_at_corner(corner, region, result)
	if not water_data.is_valid:
		return 10.0 # Terreno seco

	var water_h: float = float(water_data.water_height)
	# Distancia vertical: positiva si el terreno está por encima del agua
	return terrain_h - water_h

## Obtiene las propiedades de agua (cota, flujo, profundidad, color) en una esquina de la cuadrícula
static func _sample_water_properties_at_corner(
	corner: Vector2i,
	region: RefCounted,
	result: WorldResult
) -> Dictionary:
	# Si la esquina es una WaterCell directa en la región
	if region.has_cell(corner):
		var c = region.get_cell(corner)
		return {
			"is_valid": true,
			"water_height": c.water_height,
			"bed_height": c.bed_height,
			"depth": c.depth,
			"flow_dir": c.flow_dir,
			"water_type": c.water_type
		}

	# Si no es celda directa, promediar celdas de agua adyacentes de la región
	var total_w: float = 0.0
	var avg_water_h: float = 0.0
	var avg_bed_h: float = 0.0
	var avg_depth: float = 0.0
	var blended_flow: Vector2 = Vector2.ZERO
	var dominant_type: int = _WaterCellScript.Type.RIVER

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var npos := corner + Vector2i(dx, dy)
			if region.has_cell(npos):
				var nc = region.get_cell(npos)
				var dist: float = Vector2(float(dx), float(dy)).length()
				var weight: float = 1.0 / dist
				total_w += weight
				avg_water_h += nc.water_height * weight
				avg_bed_h += nc.bed_height * weight
				avg_depth += nc.depth * weight
				blended_flow += nc.flow_dir * weight
				if nc.is_lake() or nc.is_transition():
					dominant_type = nc.water_type

	if total_w > 0.0001:
		return {
			"is_valid": true,
			"water_height": avg_water_h / total_w,
			"bed_height": avg_bed_h / total_w,
			"depth": avg_depth / total_w,
			"flow_dir": (blended_flow / total_w).normalized() if blended_flow.length_squared() > 0.0001 else Vector2.ZERO,
			"water_type": dominant_type
		}

	return {"is_valid": false}

## Obtiene o crea un vértice soldado para una esquina exacta de celda
static func _get_or_create_corner_vertex(
	surf: RefCounted,
	corner_grid: Vector2i,
	pos_2d: Vector2,
	region: RefCounted,
	result: WorldResult,
	profile: WorldProfile,
	vertex_cache: Dictionary
) -> int:
	var qx: int = corner_grid.x
	var qz: int = corner_grid.y
	var key: int = (qx << 32) | (qz & 0xFFFFFFFF)
	if vertex_cache.has(key):
		return vertex_cache[key]

	var props: Dictionary = _sample_water_properties_at_corner(corner_grid, region, result)
	var water_y: float = float(props.get("water_height", 0.0))
	var flow: Vector2 = props.get("flow_dir", Vector2.ZERO)
	var w_type: int = int(props.get("water_type", _WaterCellScript.Type.RIVER))
	var depth: float = float(props.get("depth", 0.3))

	var col: Color = _determine_water_color(w_type, depth, profile)
	var pos_3d := Vector3(pos_2d.x, water_y, pos_2d.y)

	var idx: int = surf.add_vertex(pos_3d, Vector3.UP, pos_2d, flow, col)
	vertex_cache[key] = idx
	return idx

## Obtiene o crea un vértice soldado en el cruce de orilla sobre una arista entre dos esquinas
static func _get_or_create_edge_split_vertex(
	surf: RefCounted,
	c_a: Vector2i,
	c_b: Vector2i,
	pos_2d: Vector2,
	region: RefCounted,
	result: WorldResult,
	profile: WorldProfile,
	edge_cache: Dictionary
) -> int:
	var key_a: int = (c_a.x << 32) | (c_a.y & 0xFFFFFFFF)
	var key_b: int = (c_b.x << 32) | (c_b.y & 0xFFFFFFFF)
	var min_k: int = mini(key_a, key_b)
	var max_k: int = maxi(key_a, key_b)
	var edge_key: int = (min_k * 31) ^ max_k

	if edge_cache.has(edge_key):
		return edge_cache[edge_key]

	var props_a: Dictionary = _sample_water_properties_at_corner(c_a, region, result)
	var props_b: Dictionary = _sample_water_properties_at_corner(c_b, region, result)

	var y_a: float = float(props_a.get("water_height", 0.0))
	var y_b: float = float(props_b.get("water_height", 0.0))
	var water_y: float = (y_a + y_b) * 0.5

	var flow_a: Vector2 = props_a.get("flow_dir", Vector2.ZERO)
	var flow_b: Vector2 = props_b.get("flow_dir", Vector2.ZERO)
	var flow: Vector2 = (flow_a + flow_b).normalized() if (flow_a + flow_b).length_squared() > 0.0001 else Vector2.ZERO

	var w_type: int = int(props_a.get("water_type", _WaterCellScript.Type.RIVER))
	var depth: float = (float(props_a.get("depth", 0.2)) + float(props_b.get("depth", 0.2))) * 0.5

	var col: Color = _determine_water_color(w_type, depth, profile)
	var pos_3d := Vector3(pos_2d.x, water_y, pos_2d.y)

	var idx: int = surf.add_vertex(pos_3d, Vector3.UP, pos_2d, flow, col)
	edge_cache[edge_key] = idx
	return idx

## Triangula un quad recortado por la orilla (shoreline polygon clipping)
static func _tessellate_clipped_quad(
	surf: RefCounted,
	corners_grid: Array[Vector2i],
	corners_2d: Array[Vector2],
	distances: Array[float],
	region: RefCounted,
	result: WorldResult,
	profile: WorldProfile,
	corner_cache: Dictionary,
	edge_cache: Dictionary
) -> void:
	var poly_indices: Array[int] = []

	for k in range(4):
		var k_next: int = (k + 1) % 4
		var c_curr: Vector2i = corners_grid[k]
		var c_next: Vector2i = corners_grid[k_next]
		var p_curr: Vector2 = corners_2d[k]
		var p_next: Vector2 = corners_2d[k_next]
		var d_curr: float = distances[k]
		var d_next: float = distances[k_next]

		# Si el vértice actual está sumergido, añadirlo al polígono
		if d_curr <= 0.0:
			var idx: int = _get_or_create_corner_vertex(surf, c_curr, p_curr, region, result, profile, corner_cache)
			if poly_indices.is_empty() or poly_indices[-1] != idx:
				poly_indices.append(idx)

		# Si hay cruce de orilla en esta arista, calcular el punto de corte
		if (d_curr <= 0.0 and d_next > 0.0) or (d_curr > 0.0 and d_next <= 0.0):
			var span: float = d_next - d_curr
			var frac: float = clampf(-d_curr / span, 0.0, 1.0) if absf(span) > 0.00001 else 0.5
			var edge_cross_pos: Vector2 = p_curr.lerp(p_next, frac)
			var split_idx: int = _get_or_create_edge_split_vertex(surf, c_curr, c_next, edge_cross_pos, region, result, profile, edge_cache)
			if poly_indices.is_empty() or poly_indices[-1] != split_idx:
				poly_indices.append(split_idx)

	# Si el polígono tiene 3 o más vértices, triangularlo en abanico
	if poly_indices.size() >= 3:
		var root_idx: int = poly_indices[0]
		for i in range(1, poly_indices.size() - 1):
			_add_valid_triangle(surf, root_idx, poly_indices[i], poly_indices[i + 1])

## Añade un triángulo a la superficie asegurando que no sea degenerado ni plano
static func _add_valid_triangle(surf: RefCounted, i0: int, i1: int, i2: int) -> void:
	if i0 == i1 or i1 == i2 or i0 == i2:
		return

	var v0: Vector3 = surf.vertices[i0]
	var v1: Vector3 = surf.vertices[i1]
	var v2: Vector3 = surf.vertices[i2]

	var cross_prod: Vector3 = (v1 - v0).cross(v2 - v0)
	var area: float = cross_prod.length() * 0.5
	if area < 0.0001:
		return

	surf.add_triangle(i0, i1, i2)

## Determina el color de vértice para el sombreador de agua
static func _determine_water_color(w_type: int, depth: float, profile: WorldProfile) -> Color:
	if profile == null:
		return Color("#1cb0be")

	match w_type:
		_WaterCellScript.Type.LAKE:
			return profile.water_color_lake
		_WaterCellScript.Type.TRANSITION:
			return profile.water_color_river.lerp(profile.water_color_lake, 0.5)
		_WaterCellScript.Type.OUTLET:
			return profile.water_color_lake.lerp(profile.water_color_river, 0.5)
		_:
			var shallow: Color = profile.water_color_shallow
			var river_c: Color = profile.water_color_river
			var t: float = clampf(depth / 0.5, 0.0, 1.0)
			return shallow.lerp(river_c, t)
