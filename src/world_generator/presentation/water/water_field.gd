class_name WaterField
extends RefCounted

## Campo de distancias con signo (SDF 2D en el plano XZ) para la red fluvial.
##
## Representación implícita continua y unificada del agua:
## - < 0: Interior del canal de agua (sumergido).
## - = 0: Frontera exacta / orilla (shoreline).
## - > 0: Terreno seco exterior.
##
## Solapamientos resueltos mediante unión matemática continua (mínimo de distancias).
## Sin vértices izq/der, sin normales, sin parches de unión, sin trim ni miters.

var bounds_min: Vector2 = Vector2.ZERO
var bounds_max: Vector2 = Vector2.ZERO
var resolution: Vector2i = Vector2i.ZERO
var cell_size_field: Vector2 = Vector2.ONE
var margin: float = 8.0

## Matriz bidimensional accesible como water_field[x][z]
var water_field: Array = []

## Segmentos normalizados utilizados para generar el campo
var segments: Array = []

func _init(
	p_bounds_min: Vector2 = Vector2.ZERO,
	p_bounds_max: Vector2 = Vector2.ZERO,
	p_resolution: Vector2i = Vector2i(64, 64),
	p_margin: float = 8.0
) -> void:
	bounds_min = p_bounds_min
	bounds_max = p_bounds_max
	resolution = p_resolution
	margin = p_margin
	_update_cell_size()
	_allocate_grid()

func _update_cell_size() -> void:
	var span_x: float = maxf(bounds_max.x - bounds_min.x, 0.001)
	var span_z: float = maxf(bounds_max.y - bounds_min.y, 0.001)
	var denom_x: float = float(maxi(resolution.x - 1, 1))
	var denom_z: float = float(maxi(resolution.y - 1, 1))
	cell_size_field = Vector2(span_x / denom_x, span_z / denom_z)

func _allocate_grid() -> void:
	water_field.clear()
	water_field.resize(resolution.x)
	for x in range(resolution.x):
		var column: Array[float] = []
		column.resize(resolution.y)
		column.fill(INF)
		water_field[x] = column

## Fábrica principal: genera un WaterField a partir de WorldResult y segmentos normalizados o red fluvial
static func create(
	network_or_segments: Variant,
	result: WorldResult,
	profile: WorldProfile = null,
	terrain_resolution: int = -1,
	field_margin: float = -1.0
) -> WaterField:
	var cell_size: float = profile.cell_size if profile != null else 1.0

	# 1. Determinar resolución base (escalada para que nunca sea inferior a la cuadrícula de terreno)
	var res: int = terrain_resolution
	if res <= 0:
		var map_dim: int = maxi(result.dimensions.x, result.dimensions.y) if result != null else (profile.width if profile != null else 128)
		if profile != null and "water_field_resolution" in profile and profile.water_field_resolution > 0:
			res = maxi(profile.water_field_resolution, map_dim)
		else:
			res = maxi(128, map_dim)

	# 2. Extraer o normalizar segmentos
	var segs: Array = []
	if network_or_segments is Array:
		segs = network_or_segments
	elif network_or_segments != null:
		var builder_script = load("res://src/world_generator/presentation/water/river_network_mesh_builder.gd")
		if builder_script != null and builder_script.has_method("normalize_network_to_segments"):
			segs = builder_script.normalize_network_to_segments(network_or_segments)

	# 3. Determinar bounds con margen para evitar recortes
	var world_min_x: float = 0.0
	var world_max_x: float = float(res) * cell_size
	var world_min_z: float = 0.0
	var world_max_z: float = float(res) * cell_size

	if result != null and result.dimensions != Vector2i.ZERO:
		world_max_x = float(result.dimensions.x) * cell_size
		world_max_z = float(result.dimensions.y) * cell_size

	for seg in segs:
		var p0: Vector3 = seg.start_position if "start_position" in seg else seg.get("start_position", Vector3.ZERO)
		var p1: Vector3 = seg.end_position if "end_position" in seg else seg.get("end_position", Vector3.ZERO)
		world_min_x = minf(world_min_x, minf(p0.x, p1.x))
		world_max_x = maxf(world_max_x, maxf(p0.x, p1.x))
		world_min_z = minf(world_min_z, minf(p0.z, p1.z))
		world_max_z = maxf(world_max_z, maxf(p0.z, p1.z))

	var m: float = field_margin
	if m <= 0.0:
		m = maxf(cell_size * 6.0, 8.0)

	var b_min := Vector2(world_min_x - m, world_min_z - m)
	var b_max := Vector2(world_max_x + m, world_max_z + m)

	# Asegurar celdas cuadradas e isotrópicas (dx == dz) proporcionales a las dimensiones reales
	var span_x: float = maxf(b_max.x - b_min.x, 1.0)
	var span_z: float = maxf(b_max.y - b_min.y, 1.0)
	var target_spacing: float = maxf(span_x, span_z) / float(maxi(res, 32))
	var rx: int = maxi(int(round(span_x / target_spacing)), 32)
	var rz: int = maxi(int(round(span_z / target_spacing)), 32)
	var res_2d := Vector2i(rx, rz)

	var instance := WaterField.new(b_min, b_max, res_2d, m)
	instance.segments = segs
	instance._rasterize_segments(segs)
	return instance

## Rasteriza los segmentos calculando distance_to_network - width/2 con radio de influencia acotado
func _rasterize_segments(segs: Array) -> void:
	var dx: float = cell_size_field.x
	var dz: float = cell_size_field.y
	# Margen de seguridad amplio: garantiza que todas las esquinas de celdas cruzadas por la orilla
	# tengan valores SDF finitos y continuos (evitando valores INF que rompen la interpolación de Marching Squares)
	var cell_buffer: float = maxf(dx, dz) * 3.0 + 1.0

	for seg in segs:
		var p0_3d: Vector3 = seg.start_position if "start_position" in seg else seg.get("start_position", Vector3.ZERO)
		var p1_3d: Vector3 = seg.end_position if "end_position" in seg else seg.get("end_position", Vector3.ZERO)
		var w0: float = float(seg.width_start if "width_start" in seg else seg.get("width_start", 1.0))
		var w1: float = float(seg.width_end if "width_end" in seg else seg.get("width_end", 1.0))

		var p0_x: float = p0_3d.x
		var p0_z: float = p0_3d.z
		var p1_x: float = p1_3d.x
		var p1_z: float = p1_3d.z
		var vx: float = p1_x - p0_x
		var vz: float = p1_z - p0_z
		var len_sq: float = vx * vx + vz * vz
		var inv_len_sq: float = 1.0 / len_sq if len_sq > 0.00001 else 0.0

		var max_half_w: float = maxf(w0 * 0.5, w1 * 0.5)
		# Bounding box acotado estrictamente expandido por width / 2 más margen de celda para cruce por cero
		var expand: float = max_half_w + cell_buffer
		var seg_min_x: float = minf(p0_x, p1_x) - expand
		var seg_max_x: float = maxf(p0_x, p1_x) + expand
		var seg_min_z: float = minf(p0_z, p1_z) - expand
		var seg_max_z: float = maxf(p0_z, p1_z) + expand

		var ix_min: int = clampi(int(floor((seg_min_x - bounds_min.x) / dx)), 0, resolution.x - 1)
		var ix_max: int = clampi(int(ceil((seg_max_x - bounds_min.x) / dx)), 0, resolution.x - 1)
		var iz_min: int = clampi(int(floor((seg_min_z - bounds_min.y) / dz)), 0, resolution.y - 1)
		var iz_max: int = clampi(int(ceil((seg_max_z - bounds_min.y) / dz)), 0, resolution.y - 1)

		for ix in range(ix_min, ix_max + 1):
			var qx: float = bounds_min.x + float(ix) * dx
			var rx: float = qx - p0_x
			var col: Array = water_field[ix]

			for iz in range(iz_min, iz_max + 1):
				var qz: float = bounds_min.y + float(iz) * dz
				var rz: float = qz - p0_z

				# Proyección ortogonal con clamp al tramo [0, 1] en registros escalares
				var dot: float = rx * vx + rz * vz
				var t: float = clampf(dot * inv_len_sq, 0.0, 1.0)

				var proj_x: float = p0_x + vx * t
				var proj_z: float = p0_z + vz * t
				var d_x: float = qx - proj_x
				var d_z: float = qz - proj_z
				var dist_sq: float = d_x * d_x + d_z * d_z

				# Interpolar ancho en la proyección exacta del tramo
				var half_width: float = (w0 + (w1 - w0) * t) * 0.5
				var max_dist_check: float = half_width + cell_buffer

				if dist_sq <= max_dist_check * max_dist_check:
					var dist_centerline: float = sqrt(dist_sq)
					var segment_field: float = dist_centerline - half_width

					# Solapamientos: unión booleana continua min(field, seg_field)
					if segment_field < col[iz]:
						col[iz] = segment_field

## Evalúa continuamente el campo SDF en coordenadas arbitrarias del mundo (X, Z)
## mediante interpolación bilineal.
func sample_water_field(x: float, z: float) -> float:
	var dx: float = cell_size_field.x
	var dz: float = cell_size_field.y

	var gx: float = (x - bounds_min.x) / dx
	var gz: float = (z - bounds_min.y) / dz

	# Si se muestrea fuera del dominio acotado, retornar distancia de terreno seco
	if gx < 0.0 or gx > float(resolution.x - 1) or gz < 0.0 or gz > float(resolution.y - 1):
		var d_out_x: float = maxf(bounds_min.x - x, x - bounds_max.x)
		var d_out_z: float = maxf(bounds_min.y - z, z - bounds_max.y)
		var extra_dist: float = sqrt(maxf(d_out_x, 0.0) ** 2 + maxf(d_out_z, 0.0) ** 2)
		return 10.0 + extra_dist

	var ix0: int = clampi(int(floor(gx)), 0, resolution.x - 2)
	var iz0: int = clampi(int(floor(gz)), 0, resolution.y - 2)

	var fx: float = clampf(gx - float(ix0), 0.0, 1.0)
	var fz: float = clampf(gz - float(iz0), 0.0, 1.0)

	var v00: float = water_field[ix0][iz0]
	var v10: float = water_field[ix0 + 1][iz0]
	var v01: float = water_field[ix0][iz0 + 1]
	var v11: float = water_field[ix0 + 1][iz0 + 1]

	var v0: float = lerpf(v00, v10, fx)
	var v1: float = lerpf(v01, v11, fx)
	return lerpf(v0, v1, fz)

## Consulta booleana rápida: ¿el punto (x, z) se encuentra sumergido en agua?
func is_water(x: float, z: float) -> bool:
	return sample_water_field(x, z) < 0.0

## Consulta booleana rápida: ¿el punto (x, z) corresponde a tierra seca?
func is_land(x: float, z: float) -> bool:
	return sample_water_field(x, z) > 0.0

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

## Consulta la información hidrológica local (cota, flujo, profundidad) en coordenadas (x, z)
## a partir del segmento fluvial dominante en ese punto.
func get_water_data_at(x: float, z: float, _result: WorldResult = null, _profile: WorldProfile = null) -> Dictionary:
	var q := Vector2(x, z)
	var best_seg = null
	var best_dist: float = INF
	var best_t: float = 0.0

	for seg in segments:
		var p0_3d: Vector3 = seg.start_position if "start_position" in seg else seg.get("start_position", Vector3.ZERO)
		var p1_3d: Vector3 = seg.end_position if "end_position" in seg else seg.get("end_position", Vector3.ZERO)
		var w0: float = float(seg.width_start if "width_start" in seg else seg.get("width_start", 1.0))
		var w1: float = float(seg.width_end if "width_end" in seg else seg.get("width_end", 1.0))

		var p0 := Vector2(p0_3d.x, p0_3d.z)
		var p1 := Vector2(p1_3d.x, p1_3d.z)
		var v := p1 - p0
		var len_sq: float = v.length_squared()

		var t: float = 0.0
		if len_sq > 0.00001:
			t = clampf((q - p0).dot(v) / len_sq, 0.0, 1.0)

		var closest: Vector2 = p0 + v * t
		var d_centerline: float = q.distance_to(closest)
		var w_at_t: float = lerpf(w0, w1, t)
		var sdf_val: float = d_centerline - w_at_t * 0.5

		if sdf_val < best_dist:
			best_dist = sdf_val
			best_seg = seg
			best_t = t

	if best_seg == null:
		return {
			"elevation": 0.0,
			"flow": Vector2(0.0, 1.0),
			"depth": 0.2,
			"river_id": -1,
			"order": 1
		}

	var p0_3d: Vector3 = best_seg.start_position if "start_position" in best_seg else best_seg.get("start_position", Vector3.ZERO)
	var p1_3d: Vector3 = best_seg.end_position if "end_position" in best_seg else best_seg.get("end_position", Vector3.ZERO)
	var d0: float = float(best_seg.depth_start if "depth_start" in best_seg else best_seg.get("depth_start", 0.2))
	var d1: float = float(best_seg.depth_end if "depth_end" in best_seg else best_seg.get("depth_end", 0.2))

	var depth: float = maxf(lerpf(d0, d1, best_t), 0.05)
	var f_bank: float = maxf(depth * 0.75, 0.25)
	var centerline_y: float = lerpf(p0_3d.y, p1_3d.y, best_t)
	var elev: float = centerline_y - f_bank

	var dir_3d: Vector3 = (p1_3d - p0_3d)
	var dir_2d := Vector2(dir_3d.x, dir_3d.z)
	var flow: Vector2 = dir_2d.normalized() if dir_2d.length_squared() > 0.0001 else Vector2(0.0, 1.0)

	var rid: int = best_seg.river_id if "river_id" in best_seg else best_seg.get("river_id", -1)
	var ord: int = best_seg.order if "order" in best_seg else best_seg.get("order", 1)

	return {
		"elevation": elev,
		"flow": flow,
		"depth": depth,
		"river_id": rid,
		"order": ord
	}

## Muestreo continuo exacto de la elevación del lecho de terreno
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


## Extrae la superficie de agua (WaterSurfaceData) a partir del campo SDF continuo.
## Garantiza una única región de agua conectada:
## - Sin mallas/parches de unión ni confluencia.
## - El río aguas abajo mantiene y expande su ancho naturalmente.
## - El afluente intersecta limpiamente sin generar una segunda superficie.
## - Las confluencias no son casos especiales en el pipeline.
func extract_water_surface(result: WorldResult, profile: WorldProfile = null) -> WaterSurfaceData:
	var surf = _WaterSurfaceDataScript.new()
	if profile == null:
		profile = WorldProfile.new()

	var dx: float = cell_size_field.x
	var dz: float = cell_size_field.y
	var vertex_cache: Dictionary = {}

	for ix in range(resolution.x - 1):
		var x0: float = bounds_min.x + float(ix) * dx
		var x1: float = bounds_min.x + float(ix + 1) * dx

		for iz in range(resolution.y - 1):
			var z0: float = bounds_min.y + float(iz) * dz
			var z1: float = bounds_min.y + float(iz + 1) * dz

			var d00: float = water_field[ix][iz]
			var d10: float = water_field[ix + 1][iz]
			var d11: float = water_field[ix + 1][iz + 1]
			var d01: float = water_field[ix][iz + 1]

			# Celda completamente seca
			if d00 > 0.0 and d10 > 0.0 and d11 > 0.0 and d01 > 0.0:
				continue

			# Si el quad está completamente inmerso dentro de un lago, lo renderiza LakeMeshBuilder
			var hydro = result.hydrology if result != null else null
			if hydro != null and hydro.has_method("is_lake"):
				var cell_sz: float = profile.cell_size if profile != null else 1.0
				var g00 := Vector2i(int(floor(x0 / cell_sz)), int(floor(z0 / cell_sz)))
				var g10 := Vector2i(int(floor(x1 / cell_sz)), int(floor(z0 / cell_sz)))
				var g11 := Vector2i(int(floor(x1 / cell_sz)), int(floor(z1 / cell_sz)))
				var g01 := Vector2i(int(floor(x0 / cell_sz)), int(floor(z1 / cell_sz)))
				if hydro.is_lake(g00) and hydro.is_lake(g10) and hydro.is_lake(g11) and hydro.is_lake(g01):
					continue

			# 1. Caso interior pleno: los 4 vértices están en agua (d <= 0.0)
			if d00 <= 0.0 and d10 <= 0.0 and d11 <= 0.0 and d01 <= 0.0:
				_emit_cell_quad_welded(surf, x0, x1, z0, z1, result, profile, vertex_cache)
				continue

			# 2. Caso frontera: recortar el polígono de agua dentro de la celda
			_emit_clipped_cell_polygon_welded(surf, x0, x1, z0, z1, d00, d10, d11, d01, result, profile, vertex_cache)

	return surf

func _get_or_add_surface_vertex(
	surf: WaterSurfaceData,
	wx: float, wz: float,
	result: WorldResult, profile: WorldProfile,
	vertex_cache: Dictionary
) -> int:
	var qx: int = int(round(wx * 200.0))
	var qz: int = int(round(wz * 200.0))
	var key: int = (qx << 32) | (qz & 0xFFFFFFFF)
	if vertex_cache.has(key):
		return vertex_cache[key]

	var dat: Dictionary = get_water_data_at(wx, wz, result, profile)
	var v_pos := Vector3(wx, float(dat.elevation), wz)
	var col: Color = profile.water_color_river
	var idx: int = surf.add_vertex(v_pos, Vector3.UP, Vector2(wx, wz), dat.flow, col)
	vertex_cache[key] = idx
	return idx

func _emit_cell_quad_welded(
	surf: WaterSurfaceData,
	x0: float, x1: float, z0: float, z1: float,
	result: WorldResult, profile: WorldProfile,
	vertex_cache: Dictionary
) -> void:
	var i00: int = _get_or_add_surface_vertex(surf, x0, z0, result, profile, vertex_cache)
	var i10: int = _get_or_add_surface_vertex(surf, x1, z0, result, profile, vertex_cache)
	var i11: int = _get_or_add_surface_vertex(surf, x1, z1, result, profile, vertex_cache)
	var i01: int = _get_or_add_surface_vertex(surf, x0, z1, result, profile, vertex_cache)

	surf.add_triangle(i00, i10, i11)
	surf.add_triangle(i00, i11, i01)

func _emit_clipped_cell_polygon_welded(
	surf: WaterSurfaceData,
	x0: float, x1: float, z0: float, z1: float,
	d00: float, d10: float, d11: float, d01: float,
	result: WorldResult, profile: WorldProfile,
	vertex_cache: Dictionary
) -> void:
	var corners: Array[Vector2] = [
		Vector2(x0, z0),
		Vector2(x1, z0),
		Vector2(x1, z1),
		Vector2(x0, z1)
	]
	var d_vals: Array[float] = [d00, d10, d11, d01]

	var poly_pts: Array[Vector2] = []

	for k in range(4):
		var k_next: int = (k + 1) % 4
		var c_curr: Vector2 = corners[k]
		var c_next: Vector2 = corners[k_next]
		var d_curr: float = d_vals[k]
		var d_next: float = d_vals[k_next]

		if d_curr <= 0.0:
			poly_pts.append(c_curr)

		# Comprobar cruce de orilla (cambio de signo en la arista)
		if (d_curr <= 0.0 and d_next > 0.0) or (d_curr > 0.0 and d_next <= 0.0):
			var span: float = d_next - d_curr
			var frac: float = clampf(-d_curr / span, 0.0, 1.0) if absf(span) > 0.00001 else 0.5
			var edge_cross: Vector2 = c_curr.lerp(c_next, frac)
			poly_pts.append(edge_cross)

	var num_pts: int = poly_pts.size()
	if num_pts < 3:
		return

	var indices_in_poly: Array[int] = []
	indices_in_poly.resize(num_pts)
	for k in range(num_pts):
		indices_in_poly[k] = _get_or_add_surface_vertex(surf, poly_pts[k].x, poly_pts[k].y, result, profile, vertex_cache)

	for k in range(1, num_pts - 1):
		var i0: int = indices_in_poly[0]
		var i1: int = indices_in_poly[k]
		var i2: int = indices_in_poly[k + 1]
		if i0 != i1 and i1 != i2 and i2 != i0:
			surf.add_triangle(i0, i1, i2)

const _RawContourScript = preload("res://src/world_generator/presentation/water/raw_contour.gd")

## Extrae contornos geométricos cerrados (RawContours[]) mediante Marching Squares en celdas 2x2.
##
## PROCESO:
## 1. Itera celdas 2x2 en la cuadrícula de water_field.
## 2. Define índice binario por esquina: inside = field < 0 (agua).
## 3. Implementa los 16 casos canónicos de Marching Squares.
## 4. Interpola cruces exactamente con t = field_a / (field_a - field_b) (sin promediar al centro).
## 5. Interconecta puntos equivalentes entre celdas mediante claves unificadas de arista.
## 6. Resuelve casos ambiguos (saddles 5 y 10) usando el valor bilineal del centro de la celda.
## 7. Mantiene contornos independientes para cada cuerpo de agua y lazos cerrados.
## 8. Post-identifica componentes conexos e islas/huecos mediante inclusión topológica.
func extract_raw_contours() -> Array:
	var dx: float = cell_size_field.x
	var dz: float = cell_size_field.y

	var edge_points: Dictionary = {}    # edge_key -> Vector2
	var forward_links: Dictionary = {}  # edge_key -> edge_key

	for ix in range(resolution.x - 1):
		var x0: float = bounds_min.x + float(ix) * dx
		var x1: float = bounds_min.x + float(ix + 1) * dx

		for iz in range(resolution.y - 1):
			var z0: float = bounds_min.y + float(iz) * dz
			var z1: float = bounds_min.y + float(iz + 1) * dz

			var f0: float = water_field[ix][iz]
			var f1: float = water_field[ix + 1][iz]
			var f2: float = water_field[ix + 1][iz + 1]
			var f3: float = water_field[ix][iz + 1]

			# 2. Índice binario por esquina (inside = field < 0)
			var mask: int = 0
			if f0 < 0.0: mask |= 1
			if f1 < 0.0: mask |= 2
			if f2 < 0.0: mask |= 4
			if f3 < 0.0: mask |= 8

			# Casos triviales: celda 100% tierra (0) o 100% agua (15)
			if mask == 0 or mask == 15:
				continue

			# 4. Interpolar cruces de aristas: t = field_a / (field_a - field_b)
			# Arista 0 (Norte/Top: C0 -> C1)
			var k_e0: int = (0 << 32) | (ix << 16) | iz
			if not edge_points.has(k_e0) and ((f0 < 0.0 and f1 >= 0.0) or (f0 >= 0.0 and f1 < 0.0)):
				var span0: float = f0 - f1
				var t0: float = clampf(f0 / span0, 0.0, 1.0) if absf(span0) > 0.00001 else 0.5
				edge_points[k_e0] = Vector2(lerpf(x0, x1, t0), z0)

			# Arista 1 (Este/Right: C1 -> C2)
			var k_e1: int = (1 << 32) | ((ix + 1) << 16) | iz
			if not edge_points.has(k_e1) and ((f1 < 0.0 and f2 >= 0.0) or (f1 >= 0.0 and f2 < 0.0)):
				var span1: float = f1 - f2
				var t1: float = clampf(f1 / span1, 0.0, 1.0) if absf(span1) > 0.00001 else 0.5
				edge_points[k_e1] = Vector2(x1, lerpf(z0, z1, t1))

			# Arista 2 (Sur/Bottom: C3 -> C2)
			var k_e2: int = (0 << 32) | (ix << 16) | (iz + 1)
			if not edge_points.has(k_e2) and ((f3 < 0.0 and f2 >= 0.0) or (f3 >= 0.0 and f2 < 0.0)):
				var span2: float = f3 - f2
				var t2: float = clampf(f3 / span2, 0.0, 1.0) if absf(span2) > 0.00001 else 0.5
				edge_points[k_e2] = Vector2(lerpf(x0, x1, t2), z1)

			# Arista 3 (Oeste/Left: C0 -> C3)
			var k_e3: int = (1 << 32) | (ix << 16) | iz
			if not edge_points.has(k_e3) and ((f0 < 0.0 and f3 >= 0.0) or (f0 >= 0.0 and f3 < 0.0)):
				var span3: float = f0 - f3
				var t3: float = clampf(f0 / span3, 0.0, 1.0) if absf(span3) > 0.00001 else 0.5
				edge_points[k_e3] = Vector2(x0, lerpf(z0, z1, t3))

			# 3 y 6. Tabla canónica de 16 casos MS con resolución de ambigüedad 5 y 10
			var segments_in_cell: Array = []

			match mask:
				1:  # C0 inside
					segments_in_cell.append([k_e3, k_e0])
				2:  # C1 inside
					segments_in_cell.append([k_e0, k_e1])
				3:  # C0, C1 inside
					segments_in_cell.append([k_e3, k_e1])
				4:  # C2 inside
					segments_in_cell.append([k_e1, k_e2])
				5:  # Saddle C0, C2 inside (ambiguo)
					var center_f5: float = (f0 + f1 + f2 + f3) * 0.25
					if center_f5 < 0.0:
						segments_in_cell.append([k_e3, k_e2])
						segments_in_cell.append([k_e1, k_e0])
					else:
						segments_in_cell.append([k_e3, k_e0])
						segments_in_cell.append([k_e1, k_e2])
				6:  # C1, C2 inside
					segments_in_cell.append([k_e0, k_e2])
				7:  # C0, C1, C2 inside (solo C3 outside)
					segments_in_cell.append([k_e3, k_e2])
				8:  # C3 inside
					segments_in_cell.append([k_e2, k_e3])
				9:  # C0, C3 inside
					segments_in_cell.append([k_e2, k_e0])
				10: # Saddle C1, C3 inside (ambiguo)
					var center_f10: float = (f0 + f1 + f2 + f3) * 0.25
					if center_f10 < 0.0:
						segments_in_cell.append([k_e0, k_e3])
						segments_in_cell.append([k_e2, k_e1])
					else:
						segments_in_cell.append([k_e0, k_e1])
						segments_in_cell.append([k_e2, k_e3])
				11: # C0, C1, C3 inside (solo C2 outside)
					segments_in_cell.append([k_e2, k_e1])
				12: # C2, C3 inside
					segments_in_cell.append([k_e1, k_e3])
				13: # C0, C2, C3 inside (solo C1 outside)
					segments_in_cell.append([k_e1, k_e0])
				14: # C1, C2, C3 inside (solo C0 outside)
					segments_in_cell.append([k_e0, k_e3])

			for seg in segments_in_cell:
				forward_links[seg[0]] = seg[1]

	# 5 y 7. Interconectar puntos equivalentes en contornos cerrados independientes
	var visited: Dictionary = {}
	var raw_contours: Array = []

	for start_key in forward_links.keys():
		if visited.has(start_key):
			continue

		var loop_pts: PackedVector2Array = PackedVector2Array()
		var curr_key = start_key
		var is_closed := false

		while curr_key != null and not visited.has(curr_key):
			visited[curr_key] = true
			if edge_points.has(curr_key):
				loop_pts.append(edge_points[curr_key])

			var next_key = forward_links.get(curr_key, null)
			if next_key == null:
				break

			if next_key == start_key:
				if edge_points.has(start_key):
					loop_pts.append(edge_points[start_key])
				is_closed = true
				break

			curr_key = next_key

		if loop_pts.size() >= 3:
			if not is_closed:
				loop_pts.append(loop_pts[0])
				is_closed = true

			var contour = _RawContourScript.new(loop_pts, 0)
			contour.is_closed = is_closed
			raw_contours.append(contour)

	# 8. Post-identificar componentes conexos
	var outer_contours: Array = []
	var hole_contours: Array = []

	for c in raw_contours:
		if not c.is_hole and c.is_closed:
			outer_contours.append(c)
		else:
			hole_contours.append(c)

	var next_comp_id: int = 1
	for outer in outer_contours:
		outer.component_id = next_comp_id
		next_comp_id += 1

	for hole in hole_contours:
		var assigned := false
		var test_pt: Vector2 = hole.points[0] if not hole.points.is_empty() else Vector2.ZERO

		for outer in outer_contours:
			if outer.bounds.encloses(hole.bounds) or outer.bounds.intersects(hole.bounds):
				if Geometry2D.is_point_in_polygon(test_pt, outer.points):
					hole.component_id = outer.component_id
					assigned = true
					break

		if not assigned:
			hole.component_id = next_comp_id
			next_comp_id += 1

	return raw_contours

const _CleanContourScript = preload("res://src/world_generator/presentation/water/clean_contour.gd")

## Extrae contornos geométricos limpios (CleanContours[]) aplicando el pipeline de 5 pasos:
## 1. Quitar duplicados.
## 2. Quitar aristas longitud cero.
## 3. Quitar aristas diminutas (< epsilon), preservando cambios importantes.
## 4. Quitar puntos casi colineales (< angular_tolerance).
## 5. Simplificar por error geométrico máximo (RDP con max_error).
## Reglas: first != last, winding consistente, size >= 3, área > epsilon.
func extract_clean_contours(
	epsilon: float = 0.05,
	angular_tol_deg: float = 2.5,
	max_geometric_error: float = 0.08
) -> Array:
	var raw := extract_raw_contours()
	return _CleanContourScript.clean_contours(raw, epsilon, angular_tol_deg, max_geometric_error)

const _WaterPolygonScript = preload("res://src/world_generator/presentation/water/water_polygon.gd")

## Extrae una lista de WaterPolygon válidos (exterior, agujeros[]) a partir de los contornos limpios.
## - Confluencias conectadas forman parte del mismo polígono exterior continuo.
## - Islas interiores son asignadas como agujeros (holes) mediante PIP.
func extract_water_polygons(
	epsilon: float = 0.05,
	angular_tol_deg: float = 2.5,
	max_geometric_error: float = 0.08,
	minimum_polygon_area: float = 0.20
) -> Array[WaterPolygon]:
	var clean := extract_clean_contours(epsilon, angular_tol_deg, max_geometric_error)
	return _WaterPolygonScript.from_contours(clean, minimum_polygon_area)



