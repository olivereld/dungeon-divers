class_name RiverMeshBuilder
extends RefCounted

## Constructor de alto nivel para la red hidrográfica de ríos y confluencias.
## Aísla la implementación geométrica de RiverMeshBuilder desacoplando los orquestadores
## de renderizado (WaterRenderer / RiverRenderer) de los algoritmos de geometría de bajo nivel.
##
## ==============================================================================
## CONTRATO DE ENTRADA Y SALIDA (Documentación de Arquitectura):
## ==============================================================================
##
## ENTRADA (Inputs):
## 1. network: RiverNetwork (o Variant convertible/resuelto desde HydrologyResult):
##    - Grafo acíclico dirigido (DAG) de la red fluvial.
##    - Contiene 'rivers' (Array[River]) y 'confluences' (Array[Dictionary]).
##    - Si es null o no provisto, se resuelve automáticamente desde result.hydrology.get_river_network().
##
## 2. result: WorldResult:
##    - Contenedor canónico del mundo generado.
##    - Proporciona dimensiones del mapa (dimensions), celdas de terreno para muestreo de lecho
##      y contexto hidrológico general (result.hydrology).
##
## 3. profile: WorldProfile:
##    - Configuración física y visual de la generación (cell_size, water_level_min_offset,
##      colores de agua, ancho mínimo de río, etc.).
##
## SALIDA (Output):
## - WaterSurfaceData:
##    - Objeto unificado que encapsula la geometría completa de la red de agua:
##      * vertices (PackedVector3Array)
##      * normals (PackedVector3Array)
##      * uvs (PackedVector2Array)
##      * uv2_flow (PackedVector2Array) - codificación vectorial de flujo continuo
##      * colors (PackedColorArray)
##      * indices (PackedInt32Array)
##    - Se convierte directamente a ArrayMesh mediante .to_array_mesh() o se agrega a
##      superficies combinadas (WaterRenderer).
##
## RESTRICCIÓN DE DISEÑO:
## - No implementa nuevos algoritmos geométricos aún; reutiliza y aísla la generación
##   probada de RiverMeshBuilder (ribbons longitudinales y patches de confluencia).
## ==============================================================================

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverNetworkScript = preload("res://src/world_generator/hydrology/river_network.gd")
const _RenderSegmentScript = preload("res://src/world_generator/presentation/water/render_segment.gd")
const _WaterFieldScript = preload("res://src/world_generator/presentation/water/water_field.gd")
const _RawContourScript = preload("res://src/world_generator/presentation/water/raw_contour.gd")
const _CleanContourScript = preload("res://src/world_generator/presentation/water/clean_contour.gd")
const _WaterPolygonScript = preload("res://src/world_generator/presentation/water/water_polygon.gd")

## Normaliza una RiverNetwork (o colección de ríos) a un arreglo lineal de RenderSegment[].
##
## PROCESO:
## 1. Itera ríos ignorando ríos sin puntos, con geometría inválida o ancho <= 0.
## 2. Copia datos sin modificar el original.
## 3. Limpia centerlines eliminando duplicados y segmentos menores a epsilon (manteniendo extremos e interpolando W/D).
## 4. Convierte cada tramo consecutivo (P0, W0, D0 -> P1, W1, D1) a RenderSegment.
##
## RESTRICCIONES:
## - No modifica el original.
## - Sin suavizado (mantiene las líneas base limpias sin convoluciones ni splines).
## - Sin vértices de malla (puramente geométrico-descriptivo).
static func normalize_network_to_segments(
	network: Variant,
	epsilon: float = 0.001
) -> Array[RenderSegment]:
	var segments: Array[RenderSegment] = []
	if network == null:
		return segments

	var rivers: Array = []
	if network is _RiverNetworkScript or (network is Object and "rivers" in network):
		rivers = network.rivers
	elif network is Array:
		rivers = network
	elif network is Dictionary and "rivers" in network:
		rivers = network["rivers"]

	for river in rivers:
		var river_segs: Array[RenderSegment] = normalize_river_to_segments(river, epsilon)
		segments.append_array(river_segs)

	return segments

## Normaliza un río individual a una lista de RenderSegment
static func normalize_river_to_segments(
	river: Variant,
	epsilon: float = 0.001
) -> Array[RenderSegment]:
	var result_segments: Array[RenderSegment] = []
	if river == null:
		return result_segments

	# 1. Ignorar: sin puntos (< 2 puntos)
	var raw_pts: Array = river.points if (river is Object and "points" in river) else (river.get("points", []) if river is Dictionary else [])
	if raw_pts == null or raw_pts.size() < 2:
		return result_segments

	# 1. Ignorar: geom. inválida (puntos con coordenadas no finitas o tipos erróneos)
	for p in raw_pts:
		if not (p is Vector3) or not is_finite(p.x) or not is_finite(p.y) or not is_finite(p.z):
			return result_segments

	# 1. Ignorar: ancho <= 0
	var raw_widths: Array = river.widths if (river is Object and "widths" in river) else (river.get("widths", []) if river is Dictionary else [])
	if raw_widths == null or raw_widths.is_empty():
		return result_segments

	var max_w: float = -INF
	for w in raw_widths:
		max_w = maxf(max_w, float(w))
	if max_w <= 0.0:
		return result_segments

	# 2. Copiar datos (RESTRICCIÓN: No modificar original)
	var pts: Array[Vector3] = []
	for p in raw_pts:
		pts.append(Vector3(p.x, p.y, p.z))

	var widths: Array[float] = []
	for w in raw_widths:
		widths.append(float(w))

	var raw_depths: Array = river.depths if (river is Object and "depths" in river) else (river.get("depths", []) if river is Dictionary else [])
	var depths: Array[float] = []
	if raw_depths != null:
		for d in raw_depths:
			depths.append(float(d))

	var river_id: int = river.id if (river is Object and "id" in river) else (river.get("id", -1) if river is Dictionary else -1)
	var order: int = river.order if (river is Object and "order" in river) else (river.get("order", 1) if river is Dictionary else 1)

	# Interpolar W/D si las longitudes de arreglo no coinciden con la cantidad de puntos
	var total_pts: int = pts.size()
	if widths.size() != total_pts:
		widths = _interpolate_float_array(widths, pts, 1.0)
	if depths.size() != total_pts:
		depths = _interpolate_float_array(depths, pts, 0.2)

	# 3. Limpiar centerlines: eliminar duplicados/segs < epsilon. Interpolar W/D. Mantener extremos.
	# RESTRICCIONES: Sin suavizado.
	var clean_pts: Array[Vector3] = []
	var clean_w: Array[float] = []
	var clean_d: Array[float] = []

	clean_pts.append(pts[0])
	clean_w.append(widths[0])
	clean_d.append(depths[0])

	for i in range(1, total_pts - 1):
		var d: float = pts[i].distance_to(clean_pts[-1])
		if d >= epsilon:
			clean_pts.append(pts[i])
			clean_w.append(widths[i])
			clean_d.append(depths[i])

	# Mantener extremos: el punto final se preserva
	var end_pt: Vector3 = pts[total_pts - 1]
	var end_w: float = widths[total_pts - 1]
	var end_d: float = depths[total_pts - 1]

	var dist_to_last: float = end_pt.distance_to(clean_pts[-1])
	if dist_to_last >= epsilon:
		clean_pts.append(end_pt)
		clean_w.append(end_w)
		clean_d.append(end_d)
	else:
		if clean_pts.size() > 1:
			if end_pt.distance_to(clean_pts[-2]) >= epsilon:
				clean_pts[-1] = end_pt
				clean_w[-1] = end_w
				clean_d[-1] = end_d
			else:
				while clean_pts.size() > 1 and end_pt.distance_to(clean_pts[-1]) < epsilon:
					clean_pts.pop_back()
					clean_w.pop_back()
					clean_d.pop_back()
				if not clean_pts.is_empty() and end_pt.distance_to(clean_pts[-1]) >= epsilon:
					clean_pts.append(end_pt)
					clean_w.append(end_w)
					clean_d.append(end_d)
		else:
			clean_pts.clear()

	if clean_pts.size() < 2:
		return result_segments

	# 4. Convertir tramos (P0,W0,D0 -> P1,W1,D1) a RenderSegment.
	# RESTRICCIÓN: Sin vértices.
	for j in range(clean_pts.size() - 1):
		var p0: Vector3 = clean_pts[j]
		var p1: Vector3 = clean_pts[j + 1]
		var w0: float = clean_w[j]
		var w1: float = clean_w[j + 1]
		var d0: float = clean_d[j]
		var d1: float = clean_d[j + 1]

		if w0 <= 0.0 and w1 <= 0.0:
			continue

		var seg := _RenderSegmentScript.new(
			p0,
			p1,
			w0,
			w1,
			d0,
			d1,
			river_id,
			order
		)
		result_segments.append(seg)

	return result_segments

static func _interpolate_float_array(values: Array[float], pts: Array[Vector3], default_val: float) -> Array[float]:
	var n: int = pts.size()
	var result: Array[float] = []
	if n == 0:
		return result

	if values.is_empty():
		for _i in range(n):
			result.append(default_val)
		return result

	if values.size() == 1:
		for _i in range(n):
			result.append(values[0])
		return result

	if values.size() == n:
		return values.duplicate()

	var cum_dists: Array[float] = [0.0]
	var total_len: float = 0.0
	for i in range(1, n):
		total_len += pts[i].distance_to(pts[i - 1])
		cum_dists.append(total_len)

	var num_vals: int = values.size()
	for i in range(n):
		var t: float = cum_dists[i] / total_len if total_len > 0.0001 else float(i) / float(maxi(n - 1, 1))
		var val_idx_float: float = t * float(num_vals - 1)
		var idx0: int = clampi(int(floor(val_idx_float)), 0, num_vals - 1)
		var idx1: int = clampi(idx0 + 1, 0, num_vals - 1)
		var frac: float = val_idx_float - float(idx0)
		result.append(lerpf(values[idx0], values[idx1], frac))

	return result

## Punto de entrada canónico de presentación para construir la malla de la red hidrográfica.
## Se invoca UNA SOLA VEZ por red completa (RiverNetwork) para preservar la topología global continua,
## resolver confluencias por unión matemática y evitar la fragmentación en parches o piezas aisladas.
static func build_network_mesh(
	river_network: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null
) -> WaterSurfaceData:
	return build_network_surface(river_network, result, profile)

## Alias canónico compatible: construye la superficie completa de la red hidrográfica
## como una única región continua de agua conectada (SDF y polígonos triangulados).
##
## CONTRATO DE CONFLUENCIAS UNIFICADAS:
## - Procesa todos los segmentos antes de extraer geometría.
## - La unión se resuelve matemáticamente mediante min(campos).
## - Sin mallas ni parches de unión/confluencia separados.
## - Río abajo aumenta ancho naturalmente por acumulación y orden.
## - El tributario intersecta directamente sin segunda superficie.
## - Las confluencias no son casos especiales del renderizador.
static func build_network_surface(
	network: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null
) -> WaterSurfaceData:
	if profile == null:
		profile = WorldProfile.new()

	# 1. Normalizar toda la red fluvial a RenderSegment[] sin recortes ni casos especiales
	var segments: Array[RenderSegment] = normalize_network_to_segments(network)
	if segments.is_empty():
		return _WaterSurfaceDataScript.new()

	# 2. Generar WaterPolygons y triangular a malla 2D limpia
	var mesh_2d: Dictionary = triangulate_water_mesh_2d(segments, result, profile)

	# 3. Convertir puntos 2D (XZ) a vértices 3D mediante water_height(x, z) = terrain + river_depth
	#    (sin calcular Y por triángulo, sin previous_water_y, manteniendo continuidad de altura)
	if not mesh_2d.get("vertices_2d", PackedVector2Array()).is_empty():
		return build_surface_from_2d_mesh(mesh_2d, result, profile, segments)

	# Fallback a extracción directa del SDF si la triangulación 2D no produjo geometría
	var field: WaterField = _WaterFieldScript.create(segments, result, profile)
	var fallback_surf: WaterSurfaceData = field.extract_water_surface(result, profile)
	smooth_surface_elevation(fallback_surf, result, profile)
	derive_surface_normals(fallback_surf)
	return fallback_surf

## Construye la superficie de un río individual reutilizando el pipeline unificado de red.
static func build_river_surface(
	river: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	network: Variant = null
) -> WaterSurfaceData:
	if profile == null:
		profile = WorldProfile.new()
	if network != null:
		return build_network_mesh(network, result, profile)
	return build_network_mesh([river], result, profile)

## Las confluencias no son casos especiales: quedan unificadas en la red global.
static func build_confluence_surface(
	conf: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	network: Variant = null,
	_boundary_divisions: int = 3
) -> WaterSurfaceData:
	if profile == null:
		profile = WorldProfile.new()
	if network != null:
		return build_network_mesh(network, result, profile)
	return _WaterSurfaceDataScript.new()

## Genera un WaterField (campo SDF en XZ) para la red fluvial o segmentos dados.
## Cumple con:
## - Bounds derivados de WorldResult con margen anti-recorte.
## - Resolución terrain_resolution x terrain_resolution.
## - water_field[x][z] = distance_to_network - width/2.
## - Contribución acotada al radio de influencia e interpolación continua de anchos.
## - < 0 (agua), = 0 (frontera/orilla), > 0 (terreno).
## - Solapamientos unificados mediante min(field, segment_field).
static func build_water_field(
	network_or_segments: Variant,
	result: WorldResult,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	margin: float = -1.0
) -> WaterField:
	return _WaterFieldScript.create(network_or_segments, result, profile, terrain_resolution, margin)

## Extrae contornos geométricos cerrados (RawContours[]) mediante Marching Squares 2x2.
static func extract_raw_contours(
	network_or_field: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	margin: float = -1.0
) -> Array:
	var field: WaterField = null
	if network_or_field is _WaterFieldScript:
		field = network_or_field
	else:
		field = build_water_field(network_or_field, result, profile, terrain_resolution, margin)
	return field.extract_raw_contours()

## Extrae contornos geométricos limpios (CleanContours[]) sin ruido y preservando la forma.
## Aplica: 1. Quitar duplicados -> 2. Quitar aristas cero -> 3. Quitar aristas diminutas ->
## 4. Quitar casi colineales -> 5. RDP por error geométrico máximo.
static func extract_clean_contours(
	network_or_field: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	margin: float = -1.0,
	epsilon: float = -1.0,
	angular_tol_deg: float = 2.5,
	max_geometric_error: float = -1.0
) -> Array:
	var res: int = terrain_resolution
	if res <= 0 and profile != null and "water_field_resolution" in profile:
		res = profile.water_field_resolution
	var eps: float = epsilon
	if eps < 0.0:
		eps = profile.minimum_contour_edge if (profile != null and "minimum_contour_edge" in profile) else 0.05
	var max_err: float = max_geometric_error
	if max_err < 0.0:
		max_err = profile.contour_simplification_tolerance if (profile != null and "contour_simplification_tolerance" in profile) else 0.08
	var raw_contours: Array = extract_raw_contours(network_or_field, result, profile, res, margin)
	return _CleanContourScript.clean_contours(raw_contours, eps, angular_tol_deg, max_err)

## Genera una lista de WaterPolygon válidos (exterior, agujeros[]) para cuerpos de agua únicos o múltiples.
## - Confluencias conectadas forman parte del mismo polígono continuo.
## - Detección de outer/hole mediante jerarquía PIP y paridad de anidamiento.
## - Winding consistente (CCW exterior, CW agujeros) y first != last.
static func extract_water_polygons(
	network_or_field: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	margin: float = -1.0,
	epsilon: float = -1.0,
	angular_tol_deg: float = 2.5,
	max_geometric_error: float = -1.0,
	minimum_polygon_area: float = -1.0
) -> Array[WaterPolygon]:
	var clean_contours: Array = extract_clean_contours(
		network_or_field, result, profile, terrain_resolution, margin, epsilon, angular_tol_deg, max_geometric_error
	)
	var min_area: float = minimum_polygon_area
	if min_area < 0.0:
		min_area = profile.minimum_polygon_area if (profile != null and "minimum_polygon_area" in profile) else 0.20
	return _WaterPolygonScript.from_contours(clean_contours, min_area)

## Triangula la red hidrográfica a partir de sus WaterPolygons generando una malla 2D limpia y conectada.
## Reglas:
## - Sin quads manuales, sin fans, sin ribbons, sin triángulos junction especiales.
## - Validación: área > epsilon, winding CCW estricto, sin vértices duplicados y conectividad continua.
## Retorna: Dictionary con { "vertices_2d": PackedVector2Array, "indices": PackedInt32Array }.
static func triangulate_water_mesh_2d(
	network_or_polygons: Variant,
	result: WorldResult = null,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	margin: float = -1.0,
	epsilon: float = 0.0001
) -> Dictionary:
	var polys: Array = []
	if network_or_polygons is WaterPolygon:
		polys = [network_or_polygons]
	elif network_or_polygons is Array and not network_or_polygons.is_empty() and network_or_polygons[0] is _WaterPolygonScript:
		polys = network_or_polygons
	else:
		polys = extract_water_polygons(network_or_polygons, result, profile, terrain_resolution, margin)

	return _WaterPolygonScript.triangulate_multiple_2d(polys, epsilon)

## Muestreo continuo exacto de la elevación del lecho de terreno mediante interpolación
## bilineal dividida por la diagonal de cada celda (consistente con la triangulación del terreno).
static func sample_terrain(result: WorldResult, wx: float, wz: float) -> float:
	if result == null or result.dimensions.x < 2 or result.dimensions.y < 2:
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

## Estructura de partición espacial determinista (Spatial Bins) para consultas aceleradas de segmentos.
## Evita evaluar todos los segmentos contra todos los vértices cuando la red fluvial crece.
static func build_spatial_bins(segments: Array[RenderSegment], bin_size: float = 16.0) -> Dictionary:
	var bins: Dictionary = {}
	var inv_bin_size: float = 1.0 / maxf(bin_size, 1.0)
	var num_segs: int = segments.size()

	for s_idx in range(num_segs):
		var seg := segments[s_idx]
		if seg == null:
			continue
		var p0 := seg.start_position
		var p1 := seg.end_position
		var max_half_w: float = maxf(seg.width_start, seg.width_end) * 0.5 + 4.0
		var min_x: float = minf(p0.x, p1.x) - max_half_w
		var max_x: float = maxf(p0.x, p1.x) + max_half_w
		var min_z: float = minf(p0.z, p1.z) - max_half_w
		var max_z: float = maxf(p0.z, p1.z) + max_half_w

		var bx0: int = int(floor(min_x * inv_bin_size))
		var bx1: int = int(floor(max_x * inv_bin_size))
		var bz0: int = int(floor(min_z * inv_bin_size))
		var bz1: int = int(floor(max_z * inv_bin_size))

		for bx in range(bx0, bx1 + 1):
			for bz in range(bz0, bz1 + 1):
				var bin_key := Vector2i(bx, bz)
				if not bins.has(bin_key):
					bins[bin_key] = PackedInt32Array()
				bins[bin_key].append(s_idx)

	return {
		"bin_size": bin_size,
		"inv_bin_size": inv_bin_size,
		"bins": bins,
		"segments": segments
	}

## Retorna los índices de segmentos candidatos cercanos a (x, z) usando spatial bins.
static func get_candidate_segment_indices(
	x: float,
	z: float,
	spatial_index: Dictionary,
	radius: float = 0.0
) -> PackedInt32Array:
	if spatial_index.is_empty():
		return PackedInt32Array()

	var inv_bin_size: float = float(spatial_index.get("inv_bin_size", 1.0 / 16.0))
	var bins: Dictionary = spatial_index.get("bins", {})
	var r: float = maxf(radius, 0.0)
	var bx0: int = int(floor((x - r) * inv_bin_size))
	var bx1: int = int(floor((x + r) * inv_bin_size))
	var bz0: int = int(floor((z - r) * inv_bin_size))
	var bz1: int = int(floor((z + r) * inv_bin_size))

	var candidates := PackedInt32Array()
	var seen: Dictionary = {}

	for bx in range(bx0, bx1 + 1):
		for bz in range(bz0, bz1 + 1):
			var key := Vector2i(bx, bz)
			if bins.has(key):
				var seg_indices: PackedInt32Array = bins[key]
				for idx in seg_indices:
					if not seen.has(idx):
						seen[idx] = true
						candidates.append(idx)

	return candidates

## Encuentra el segmento hidrográfico más cercano al punto 2D (x, z) e interpola sus atributos
## (profundidad, dirección de flujo y proyección paramétrica t en [0, 1]).
## Optimizado con Spatial Bins y registros escalares libres de allocations.
static func find_closest_segment_data(
	x: float,
	z: float,
	segments: Array[RenderSegment],
	spatial_index: Dictionary = {}
) -> Dictionary:
	var best_seg: RenderSegment = null
	var best_dist_sq: float = INF
	var best_t: float = 0.0

	var cand_indices: PackedInt32Array
	if not spatial_index.is_empty():
		cand_indices = get_candidate_segment_indices(x, z, spatial_index, 4.0)

	var check_all: bool = cand_indices.is_empty()
	var total_candidates: int = segments.size() if check_all else cand_indices.size()

	for k in range(total_candidates):
		var seg_idx: int = k if check_all else cand_indices[k]
		var seg: RenderSegment = segments[seg_idx]
		if seg == null:
			continue

		var p0_x: float = seg.start_position.x
		var p0_z: float = seg.start_position.z
		var p1_x: float = seg.end_position.x
		var p1_z: float = seg.end_position.z
		var vx: float = p1_x - p0_x
		var vz: float = p1_z - p0_z
		var len_sq: float = vx * vx + vz * vz

		var t: float = 0.0
		if len_sq > 0.00001:
			var rx: float = x - p0_x
			var rz: float = z - p0_z
			t = clampf((rx * vx + rz * vz) / len_sq, 0.0, 1.0)

		var proj_x: float = p0_x + vx * t
		var proj_z: float = p0_z + vz * t
		var dx_proj: float = x - proj_x
		var dz_proj: float = z - proj_z
		var d_sq: float = dx_proj * dx_proj + dz_proj * dz_proj

		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_seg = seg
			best_t = t

	if best_seg == null:
		return {
			"segment": null,
			"t": 0.0,
			"depth": 0.2,
			"flow": Vector2(0.0, 1.0),
			"distance_sq": 0.0
		}

	var d0: float = best_seg.depth_start
	var d1: float = best_seg.depth_end
	var depth: float = maxf(lerpf(d0, d1, best_t), 0.05)

	var dir_x: float = best_seg.end_position.x - best_seg.start_position.x
	var dir_z: float = best_seg.end_position.z - best_seg.start_position.z
	var dir_len_sq: float = dir_x * dir_x + dir_z * dir_z
	var flow: Vector2
	if dir_len_sq > 0.0001:
		var inv_len: float = 1.0 / sqrt(dir_len_sq)
		flow = Vector2(dir_x * inv_len, dir_z * inv_len)
	else:
		flow = Vector2(0.0, 1.0)

	return {
		"segment": best_seg,
		"t": best_t,
		"depth": depth,
		"flow": flow,
		"distance_sq": best_dist_sq
	}

## Calcula la altura continua Y de la superficie de agua en (x, z):
## water_height(x, z) = terrain + river_depth
##
## RESTRICCIONES CUMPLIDAS:
## - No calcula Y por triángulo (se evalúa por cada vértice individual en XZ).
## - Interpola river_depth del segmento hidrográfico más cercano.
## - Mantiene continuidad de altura C0 en todo el dominio.
## - Evita previous_water_y, acumuladores secuenciales o post-modificaciones.
static func water_height(
	x: float,
	z: float,
	result: WorldResult,
	segments: Array[RenderSegment]
) -> float:
	var terrain: float = sample_terrain(result, x, z)
	var seg_data: Dictionary = find_closest_segment_data(x, z, segments)
	var river_depth: float = float(seg_data.get("depth", 0.2))
	return terrain + river_depth

## Convierte un único punto 2D (x, z) a un vector 3D (x, water_height, z).
static func convert_point_2d_to_3d(
	pt_2d: Vector2,
	result: WorldResult,
	segments: Array[RenderSegment]
) -> Vector3:
	var y: float = water_height(pt_2d.x, pt_2d.y, result, segments)
	return Vector3(pt_2d.x, y, pt_2d.y)

## Convierte un arreglo de puntos 2D (XZ) a vértices 3D evaluando water_height por vértice.
## Garantiza que vértices compartidos por múltiples triángulos posean cotas idénticas sin rasgaduras.
static func convert_2d_to_3d_vertices(
	vertices_2d: PackedVector2Array,
	result: WorldResult,
	segments: Array[RenderSegment]
) -> PackedVector3Array:
	var vertices_3d := PackedVector3Array()
	var count: int = vertices_2d.size()
	vertices_3d.resize(count)
	for i in range(count):
		var p2: Vector2 = vertices_2d[i]
		var y: float = water_height(p2.x, p2.y, result, segments)
		vertices_3d[i] = Vector3(p2.x, y, p2.y)
	return vertices_3d

## Ensambla un WaterSurfaceData 3D completo a partir de la malla 2D triangulada
## adaptando la nueva geometría al sistema existente de renderizado (WaterRenderer, WaterMaterial y water_flow.gdshader).
##
## ATRIBUTOS DE VÉRTICE:
## - position: (x, water_height, z) evaluado continuamente con water_height = terrain + river_depth.
## - normal: Inicialmente Vector3.UP. Se deriva después a partir de los triángulos tras el suavizado.
## - uv: World-space XZ (Vector2(x, z)) para preservar la textura y el ruido del material existente.
## - flow_direction: Vector unitario derivado de RiverNetwork (asignado a uv2_flow).
## - water_color: Color fluvial derivado de WorldProfile (asignado a colors).
static func build_surface_from_2d_mesh(
	mesh_2d: Dictionary,
	result: WorldResult,
	profile: WorldProfile,
	segments: Array[RenderSegment],
	smooth_iterations: int = 2,
	smooth_factor: float = 0.5,
	minimum_depth: float = -1.0,
	derive_normals: bool = true
) -> WaterSurfaceData:
	var surf := _WaterSurfaceDataScript.new()
	var verts_2d: PackedVector2Array = mesh_2d.get("vertices_2d", PackedVector2Array())
	var indices: PackedInt32Array = mesh_2d.get("indices", PackedInt32Array())
	if verts_2d.is_empty() or indices.is_empty():
		return surf

	if profile == null:
		profile = WorldProfile.new()

	var num_verts: int = verts_2d.size()

	surf.vertices.resize(num_verts)
	surf.normals.resize(num_verts)
	surf.uvs.resize(num_verts)
	surf.uv2_flow.resize(num_verts)
	surf.colors.resize(num_verts)

	var use_spatial_bins: bool = segments.size() > 8
	var spatial_index: Dictionary = build_spatial_bins(segments, 16.0) if use_spatial_bins else {}

	for i in range(num_verts):
		var p2: Vector2 = verts_2d[i]
		var terrain: float = sample_terrain(result, p2.x, p2.y)
		var seg_data: Dictionary = find_closest_segment_data(p2.x, p2.y, segments, spatial_index)
		var depth: float = float(seg_data.get("depth", 0.2))
		var y: float = terrain + depth

		# 1. position: (x, water_height, z)
		surf.vertices[i] = Vector3(p2.x, y, p2.y)
		# 2. normal: Inicial Vector3.UP. Derivar después tras el suavizado.
		surf.normals[i] = Vector3.UP
		# 3. uv: Usar world-space XZ para preservar material y escalas de ruido.
		surf.uvs[i] = Vector2(p2.x, p2.y)
		# 4. flow_direction: Derivar de RiverNetwork hacia uv2_flow.
		surf.uv2_flow[i] = sample_flow_direction(p2.x, p2.y, segments, 3.0, spatial_index)
		# 5. water_color: Adaptado al perfil y sistema existente.
		surf.colors[i] = sample_water_color(p2.x, p2.y, depth, profile)

	surf.indices = indices

	# Suavizado vertical para eliminar escalones garantizando continuidad en Y
	# y respetando la restricción water_height >= terrain_height + minimum_depth sin alterar X/Z ni topología
	smooth_surface_elevation(surf, result, profile, smooth_iterations, smooth_factor, minimum_depth)

	# Derivar normales después del suavizado a partir de la geometría de los triángulos
	if derive_normals:
		derive_surface_normals(surf)

	return surf

## Suaviza verticalmente las elevaciones (Y) de una superficie de agua para evitar escalones.
##
## PROCESO:
## 1. Construye el grafo de adyacencia de la malla a partir de sus índices triangulares.
## 2. Para cada vértice, calcula la media ponderada por distancia horizontal de las elevaciones vecinas.
## 3. Interpola la elevación actual hacia la media ponderada según el factor de relajación.
## 4. Aplica estrictamente la restricción: water_height >= terrain_height + minimum_depth,
##    evitando que el agua quede bajo el terreno o por debajo del calado mínimo admisible.
##
## RESTRICCIONES CUMPLIDAS:
## - Interpola solo altura (Y). No modifica coordenadas X ni Z.
## - No modifica la topología (índices, número de vértices y triángulos permanecen idénticos).
## - Garantiza continuidad C0/C1 en Y sin escalones bruscos.
static func smooth_surface_elevation(
	surf: WaterSurfaceData,
	result: WorldResult,
	profile: WorldProfile = null,
	iterations: int = 2,
	factor: float = 0.5,
	minimum_depth: float = -1.0
) -> void:
	if surf == null or surf.vertices.is_empty() or surf.indices.is_empty():
		return

	var min_depth: float = minimum_depth
	if min_depth < 0.0:
		if profile != null and "river_min_depth" in profile:
			min_depth = float(profile.river_min_depth)
		else:
			min_depth = 0.08

	var num_verts: int = surf.vertices.size()
	var adj: Array = _build_mesh_adjacency(surf.indices, num_verts)

	var current_y: PackedFloat32Array = PackedFloat32Array()
	current_y.resize(num_verts)
	for i in range(num_verts):
		current_y[i] = surf.vertices[i].y

	var next_y: PackedFloat32Array = PackedFloat32Array()
	next_y.resize(num_verts)

	var iters: int = maxi(iterations, 1)
	var blend_factor: float = clampf(factor, 0.0, 1.0)

	for _iter in range(iters):
		for i in range(num_verts):
			var neighbors: PackedInt32Array = adj[i]
			var y_val: float = current_y[i]
			var p_i: Vector3 = surf.vertices[i]

			if neighbors.is_empty():
				next_y[i] = y_val
			else:
				var sum_w: float = 0.0
				var sum_y: float = 0.0

				for n_idx in neighbors:
					var p_n: Vector3 = surf.vertices[n_idx]
					var d_xz: float = sqrt((p_i.x - p_n.x) ** 2 + (p_i.z - p_n.z) ** 2)
					var w: float = 1.0 / maxf(d_xz, 0.01)
					sum_w += w
					sum_y += w * current_y[n_idx]

				var avg_y: float = sum_y / sum_w if sum_w > 0.00001 else y_val
				var smoothed_y: float = lerpf(y_val, avg_y, blend_factor)

				# Restricción: water_height >= terrain_height + minimum_depth
				# Evita que el agua quede bajo el terreno o por debajo del calado mínimo
				var terrain_h: float = sample_terrain(result, p_i.x, p_i.z)
				var min_allowed_h: float = terrain_h + min_depth
				next_y[i] = maxf(smoothed_y, min_allowed_h)

		# Intercambio de buffers sin re-alocaciones (.duplicate eliminado)
		var tmp_y: PackedFloat32Array = current_y
		current_y = next_y
		next_y = tmp_y

	# Asignar cotas suavizadas a los vértices sin tocar coordenadas X y Z
	for i in range(num_verts):
		var v: Vector3 = surf.vertices[i]
		surf.vertices[i] = Vector3(v.x, current_y[i], v.z)

## Versión funcional desacoplada para suavizar cotas de un arreglo de vértices 3D
## manteniendo estrictamente intactas las posiciones X/Z y la topología original.
static func smooth_mesh_elevation(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	result: WorldResult,
	profile: WorldProfile = null,
	iterations: int = 2,
	factor: float = 0.5,
	minimum_depth: float = -1.0
) -> PackedVector3Array:
	var num_verts: int = vertices.size()
	if num_verts == 0 or indices.is_empty():
		return vertices.duplicate()

	var min_depth: float = minimum_depth
	if min_depth < 0.0:
		if profile != null and "river_min_depth" in profile:
			min_depth = float(profile.river_min_depth)
		else:
			min_depth = 0.08

	var adj: Array = _build_mesh_adjacency(indices, num_verts)

	var current_y: PackedFloat32Array = PackedFloat32Array()
	current_y.resize(num_verts)
	for i in range(num_verts):
		current_y[i] = vertices[i].y

	var next_y: PackedFloat32Array = PackedFloat32Array()
	next_y.resize(num_verts)

	var iters: int = maxi(iterations, 1)
	var blend_factor: float = clampf(factor, 0.0, 1.0)

	for _iter in range(iters):
		for i in range(num_verts):
			var neighbors: PackedInt32Array = adj[i]
			var y_val: float = current_y[i]
			var p_i: Vector3 = vertices[i]

			if neighbors.is_empty():
				next_y[i] = y_val
			else:
				var sum_w: float = 0.0
				var sum_y: float = 0.0

				for n_idx in neighbors:
					var p_n: Vector3 = vertices[n_idx]
					var d_xz: float = sqrt((p_i.x - p_n.x) ** 2 + (p_i.z - p_n.z) ** 2)
					var w: float = 1.0 / maxf(d_xz, 0.01)
					sum_w += w
					sum_y += w * current_y[n_idx]

				var avg_y: float = sum_y / sum_w if sum_w > 0.00001 else y_val
				var smoothed_y: float = lerpf(y_val, avg_y, blend_factor)

				# Restricción: water_height >= terrain_height + minimum_depth
				var terrain_h: float = sample_terrain(result, p_i.x, p_i.z)
				var min_allowed_h: float = terrain_h + min_depth
				next_y[i] = maxf(smoothed_y, min_allowed_h)

		# Intercambio de buffers sin re-alocaciones (.duplicate eliminado)
		var tmp_m_y: PackedFloat32Array = current_y
		current_y = next_y
		next_y = tmp_m_y

	var smoothed_verts := PackedVector3Array()
	smoothed_verts.resize(num_verts)
	for i in range(num_verts):
		var v: Vector3 = vertices[i]
		smoothed_verts[i] = Vector3(v.x, current_y[i], v.z)

	return smoothed_verts

## Construye la lista de adyacencia de vértices a partir de la conectividad de triángulos.
static func _build_mesh_adjacency(indices: PackedInt32Array, num_vertices: int) -> Array:
	var adj_sets: Array = []
	adj_sets.resize(num_vertices)
	for i in range(num_vertices):
		adj_sets[i] = {}

	var num_indices: int = indices.size()
	for k in range(0, num_indices - 2, 3):
		var i0: int = indices[k]
		var i1: int = indices[k + 1]
		var i2: int = indices[k + 2]

		if i0 >= 0 and i0 < num_vertices and i1 >= 0 and i1 < num_vertices:
			adj_sets[i0][i1] = true
			adj_sets[i1][i0] = true

		if i1 >= 0 and i1 < num_vertices and i2 >= 0 and i2 < num_vertices:
			adj_sets[i1][i2] = true
			adj_sets[i2][i1] = true

		if i2 >= 0 and i2 < num_vertices and i0 >= 0 and i0 < num_vertices:
			adj_sets[i2][i0] = true
			adj_sets[i0][i2] = true

	var adj: Array = []
	adj.resize(num_vertices)
	for i in range(num_vertices):
		var neighbors := PackedInt32Array()
		for n in adj_sets[i].keys():
			neighbors.append(int(n))
		adj[i] = neighbors

	return adj

## Deriva las normales de la superficie a partir de la geometría de los triángulos (cross product)
## y promedia las normales en los vértices compartidos para un sombreado suave continuo.
## Las normales se inicializan en Vector3.UP y se derivan después del suavizado de elevaciones.
static func derive_surface_normals(surf: WaterSurfaceData) -> void:
	if surf == null or surf.vertices.is_empty() or surf.indices.is_empty():
		return

	var num_verts: int = surf.vertices.size()
	var accum_normals: PackedVector3Array = PackedVector3Array()
	accum_normals.resize(num_verts)
	for i in range(num_verts):
		accum_normals[i] = Vector3.ZERO

	var num_indices: int = surf.indices.size()
	for k in range(0, num_indices - 2, 3):
		var i0: int = surf.indices[k]
		var i1: int = surf.indices[k + 1]
		var i2: int = surf.indices[k + 2]

		if i0 >= 0 and i0 < num_verts and i1 >= 0 and i1 < num_verts and i2 >= 0 and i2 < num_verts:
			var v0: Vector3 = surf.vertices[i0]
			var v1: Vector3 = surf.vertices[i1]
			var v2: Vector3 = surf.vertices[i2]

			# Producto vectorial para la normal de la cara con winding CCW
			var face_norm: Vector3 = (v1 - v0).cross(v2 - v0)
			var len_sq: float = face_norm.length_squared()
			if len_sq > 0.000001:
				accum_normals[i0] += face_norm
				accum_normals[i1] += face_norm
				accum_normals[i2] += face_norm

	for i in range(num_verts):
		var n: Vector3 = accum_normals[i]
		if n.length_squared() > 0.000001:
			var n_unit: Vector3 = n.normalized()
			# Asegurar que las normales apunten hacia arriba (superficie superior de agua)
			if n_unit.y < 0.0:
				n_unit = -n_unit
			surf.normals[i] = n_unit
		else:
			surf.normals[i] = Vector3.UP

## Muestrea la dirección de flujo continuo 2D derivada de la red hidrográfica (RiverNetwork).
## Proyecta sobre los segmentos de la red e interpola el vector unitario normalizado en XZ.
## En confluencias y bifurcaciones, suaviza la transición mediante ponderación por distancia e inercia.
## Optimizado con Spatial Bins y escalares libres de allocations.
static func sample_flow_direction(
	x: float,
	z: float,
	segments: Array[RenderSegment],
	blend_radius: float = 3.0,
	spatial_index: Dictionary = {}
) -> Vector2:
	if segments.is_empty():
		return Vector2(0.0, 1.0)

	var cand_indices: PackedInt32Array
	if not spatial_index.is_empty():
		cand_indices = get_candidate_segment_indices(x, z, spatial_index, blend_radius + 4.0)

	var check_all: bool = cand_indices.is_empty()
	var total_candidates: int = segments.size() if check_all else cand_indices.size()

	var total_w: float = 0.0
	var blended_flow_x: float = 0.0
	var blended_flow_z: float = 0.0
	var best_dist_sq: float = INF
	var best_flow_x: float = 0.0
	var best_flow_z: float = 1.0

	for k in range(total_candidates):
		var seg_idx: int = k if check_all else cand_indices[k]
		var seg: RenderSegment = segments[seg_idx]
		if seg == null:
			continue

		var p0_x: float = seg.start_position.x
		var p0_z: float = seg.start_position.z
		var p1_x: float = seg.end_position.x
		var p1_z: float = seg.end_position.z
		var vx: float = p1_x - p0_x
		var vz: float = p1_z - p0_z
		var len_sq: float = vx * vx + vz * vz

		var t: float = 0.0
		if len_sq > 0.00001:
			var rx: float = x - p0_x
			var rz: float = z - p0_z
			t = clampf((rx * vx + rz * vz) / len_sq, 0.0, 1.0)

		var proj_x: float = p0_x + vx * t
		var proj_z: float = p0_z + vz * t
		var dx_proj: float = x - proj_x
		var dz_proj: float = z - proj_z
		var d_sq: float = dx_proj * dx_proj + dz_proj * dz_proj

		var dir_x: float = 0.0
		var dir_z: float = 1.0
		if len_sq > 0.00001:
			var inv_len: float = 1.0 / sqrt(len_sq)
			dir_x = vx * inv_len
			dir_z = vz * inv_len

		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_flow_x = dir_x
			best_flow_z = dir_z

		var d: float = sqrt(d_sq)
		var half_w: float = (seg.width_start + (seg.width_end - seg.width_start) * t) * 0.5
		var eff_radius: float = half_w + blend_radius
		if d < eff_radius:
			var w: float = 1.0 / maxf(d_sq + 0.01, 0.01)
			var order_factor: float = float(maxi(seg.order, 1))
			w *= order_factor
			total_w += w
			blended_flow_x += dir_x * w
			blended_flow_z += dir_z * w

	if total_w > 0.00001:
		var blended_len_sq: float = blended_flow_x * blended_flow_x + blended_flow_z * blended_flow_z
		if blended_len_sq > 0.00001:
			var inv_b: float = 1.0 / sqrt(blended_len_sq)
			return Vector2(blended_flow_x * inv_b, blended_flow_z * inv_b)

	return Vector2(best_flow_x, best_flow_z)

## Determina el color de vértice para la superficie de agua a partir de las propiedades del perfil.
## Se adapta al sistema existente (material y shader) manteniendo consistencia estética.
static func sample_water_color(
	_x: float,
	_z: float,
	depth: float,
	profile: WorldProfile = null
) -> Color:
	if profile == null:
		return Color("#1cb0be")

	var base_river_color: Color = profile.water_color_river
	if "water_color_shallow" in profile:
		var shallow_col: Color = profile.water_color_shallow
		var max_d: float = profile.river_channel_depth if "river_channel_depth" in profile else 0.5
		var t: float = clampf(depth / maxf(max_d, 0.1), 0.0, 1.0)
		return shallow_col.lerp(base_river_color, t)
	return base_river_color
