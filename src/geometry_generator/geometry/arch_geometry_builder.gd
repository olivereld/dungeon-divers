class_name ArchGeometryBuilder
extends RefCounted

## Constructor geométrico procedural especializado para arcos arquitectónicos y vanos de paso (Fase M2).
## Construye un GeneratedMesh 100% monolítico con 3 superficies (Trims, WallPanel, Bricks), normales outward CCW
## y colisiones físicas compuestas para las jambas izquierda y derecha y el dintel superior.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_arch_mesh(config = null):
	if config == null:
		config = _ArchGeometryConfigScript.new()

	var g_mesh := _GeneratedMeshScript.new()
	g_mesh.component_id = 0

	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()
	var st_bricks := SurfaceTool.new()

	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_w: float = config.width
	var total_h: float = config.height
	var wall_t: float = config.wall_thickness
	var overhang: float = config.trim_overhang
	var open_w: float = config.opening_width
	var open_h: float = config.opening_height

	var bot_h: float = config.bottom_trim_height
	var bot_slope: float = config.bottom_trim_slope_height
	var top_h: float = config.top_trim_height
	var top_slope: float = config.top_trim_slope_height
	var panel_h: float = total_h - bot_h - top_h

	var offset_x: float = -(total_w * 0.5) if config.centered_origin else 0.0
	var center_x: float = (total_w * 0.5) + offset_x

	var pillar_w: float = (total_w - open_w) * 0.5
	var half_w: float = total_w * 0.5
	var half_t: float = wall_t * 0.5

	# --------------------------------------------------------------------------
	# 1. ZÓCALOS INFERIORES (TRIMS) - PILARES IZQUIERDO Y DERECHO
	# --------------------------------------------------------------------------
	var t_bot_left := Transform3D(Basis(), Vector3(center_x - half_w + (pillar_w * 0.5), bot_h * 0.5, 0.0))
	_append_bottom_base(st_trims, pillar_w, bot_h, bot_slope, wall_t, overhang, t_bot_left)

	var t_bot_right := Transform3D(Basis(), Vector3(center_x + half_w - (pillar_w * 0.5), bot_h * 0.5, 0.0))
	_append_bottom_base(st_trims, pillar_w, bot_h, bot_slope, wall_t, overhang, t_bot_right)

	# --------------------------------------------------------------------------
	# 2. CORNISA SUPERIOR (TRIMS) - BLOQUES MODULARES CON RANURAS EN V
	# --------------------------------------------------------------------------
	var top_y: float = total_h - (top_h * 0.5)
	var center_cornice_w: float = total_w - (pillar_w * 2.0)

	var t_top_left := Transform3D(Basis(), Vector3(center_x - half_w + (pillar_w * 0.5), top_y, 0.0))
	_append_top_cornice(st_trims, pillar_w - (config.notch_width * 0.5), top_h, top_slope, wall_t, overhang, t_top_left)

	var t_top_mid := Transform3D(Basis(), Vector3(center_x, top_y, 0.0))
	_append_top_cornice(st_trims, center_cornice_w - config.notch_width, top_h, top_slope, wall_t, overhang, t_top_mid)

	var t_top_right := Transform3D(Basis(), Vector3(center_x + half_w - (pillar_w * 0.5), top_y, 0.0))
	_append_top_cornice(st_trims, pillar_w - (config.notch_width * 0.5), top_h, top_slope, wall_t, overhang, t_top_right)

	# --------------------------------------------------------------------------
	# 3. PANEL CENTRAL CON ARCO DE MEDIO PUNTO MONOLÍTICO
	# --------------------------------------------------------------------------
	var t_panel := Transform3D(Basis(), Vector3(center_x, bot_h, 0.0))
	var inner_open_h: float = open_h - bot_h
	_append_arch_wall_panel(st_panel, total_w, panel_h, wall_t, open_w, inner_open_h, config.arch_inner_bevel, t_panel)

	# --------------------------------------------------------------------------
	# 4. LADRILLOS DE RELIEVE PROCEDURALES (BRICKS)
	# --------------------------------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var noise := FastNoiseLite.new()
	noise.seed = config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = config.noise_frequency

	var left_pillar_x: float = center_x - half_w + (pillar_w * 0.5)
	var right_pillar_x: float = center_x + half_w - (pillar_w * 0.5)
	var bw: float = config.brick_width * 0.70
	var bh: float = config.brick_height

	var candidate_y_slots: Array[float] = [
		bot_h + (panel_h * 0.82),
		bot_h + (panel_h * 0.65),
		bot_h + (panel_h * 0.45),
		bot_h + (panel_h * 0.25),
		bot_h + (panel_h * 0.12)
	]

	for side in [1, -1]:
		var z_base: float = (wall_t * 0.5) if side == 1 else -(wall_t * 0.5)

		for cy in candidate_y_slots:
			var n_left: float = noise.get_noise_2d(left_pillar_x * 2.0, cy * 3.0 + float(side * 50))
			if n_left > (0.65 - (config.brick_density * 0.95)):
				var size := Vector3(bw * rng.randf_range(0.85, 1.25), bh, (bw * 0.45) * rng.randf_range(0.8, 1.2))
				var z_pos: float = z_base + ((size.z * 0.5) * float(side))
				var t_brick := Transform3D(Basis(), Vector3(left_pillar_x + rng.randf_range(-0.02, 0.02), cy, z_pos))
				_append_pillowed_brick(st_bricks, size, t_brick, 0.015)

			var n_right: float = noise.get_noise_2d(right_pillar_x * 2.0, cy * 3.0 + float(side * 50))
			if n_right > (0.65 - (config.brick_density * 0.95)):
				var size := Vector3(bw * rng.randf_range(0.85, 1.25), bh, (bw * 0.45) * rng.randf_range(0.8, 1.2))
				var z_pos: float = z_base + ((size.z * 0.5) * float(side))
				var t_brick := Transform3D(Basis(), Vector3(right_pillar_x + rng.randf_range(-0.02, 0.02), cy, z_pos))
				_append_pillowed_brick(st_bricks, size, t_brick, 0.015)

	# --------------------------------------------------------------------------
	# 5. COMMIT DE SUPERFICIES Y MATERIALES PBR
	# --------------------------------------------------------------------------
	var mesh := ArrayMesh.new()
	st_trims.generate_tangents()
	mesh = st_trims.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "Trims")

	st_panel.generate_tangents()
	mesh = st_panel.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "WallPanel")

	var brick_arrays = st_bricks.commit_to_arrays()
	if brick_arrays.size() > 0 and brick_arrays[Mesh.ARRAY_VERTEX] != null and brick_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, brick_arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "Bricks")

	g_mesh.mesh = mesh
	g_mesh.bounds = AABB(Vector3(-half_w + center_x, 0.0, -half_t - overhang), Vector3(total_w, total_h, wall_t + overhang * 2.0))

	# Aplicar Materiales PBR
	g_mesh.material_slots[0] = _WallMaterialFactoryScript.create_trim_material()
	g_mesh.material_slots[1] = _WallMaterialFactoryScript.create_panel_material()
	if mesh.get_surface_count() > 2:
		g_mesh.material_slots[2] = _WallMaterialFactoryScript.create_brick_material()

	# --------------------------------------------------------------------------
	# 6. FORMAS DE COLISIÓN FÍSICA
	# --------------------------------------------------------------------------
	# Colisión Pilar Izquierdo
	var col_left := BoxShape3D.new()
	col_left.size = Vector3(pillar_w, total_h, wall_t)
	g_mesh.add_collision_shape(col_left, Transform3D(Basis(), Vector3(center_x - half_w + (pillar_w * 0.5), total_h * 0.5, 0.0)))

	# Colisión Pilar Derecho
	var col_right := BoxShape3D.new()
	col_right.size = Vector3(pillar_w, total_h, wall_t)
	g_mesh.add_collision_shape(col_right, Transform3D(Basis(), Vector3(center_x + half_w - (pillar_w * 0.5), total_h * 0.5, 0.0)))

	# Colisión Dintel Superior
	var lintel_h: float = total_h - open_h
	if lintel_h > 0.1:
		var col_lintel := BoxShape3D.new()
		col_lintel.size = Vector3(open_w, lintel_h, wall_t)
		g_mesh.add_collision_shape(col_lintel, Transform3D(Basis(), Vector3(center_x, open_h + (lintel_h * 0.5), 0.0)))

	return g_mesh

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS INTERNOS
# ==============================================================================

static func _append_bottom_base(
	st: SurfaceTool, length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D
) -> void:
	var h_slope: float = clampf(slope_height, 0.02, total_height * 0.45)
	var h_main: float = total_height - h_slope
	var w_thin: float = wall_thickness
	var w_thick: float = wall_thickness + (trim_overhang * 2.0)
	var half_len: float = length * 0.5
	var half_w_thick: float = w_thick * 0.5
	var half_w_thin: float = w_thin * 0.5
	var half_h: float = total_height * 0.5

	var y_top: float = half_h
	var y_mid: float = -half_h + h_main
	var y_bot: float = -half_h

	_add_quad_direct(st, transform, Vector3(-half_len, y_bot, -half_w_thick), Vector3(half_len, y_bot, -half_w_thick), Vector3(half_len, y_bot, half_w_thick), Vector3(-half_len, y_bot, half_w_thick))
	_add_quad_direct(st, transform, Vector3(-half_len, y_bot, half_w_thick), Vector3(half_len, y_bot, half_w_thick), Vector3(half_len, y_mid, half_w_thick), Vector3(-half_len, y_mid, half_w_thick))
	_add_quad_direct(st, transform, Vector3(-half_len, y_mid, half_w_thick), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_top, half_w_thin), Vector3(-half_len, y_top, half_w_thin))
	_add_quad_direct(st, transform, Vector3(half_len, y_bot, -half_w_thick), Vector3(-half_len, y_bot, -half_w_thick), Vector3(-half_len, y_mid, -half_w_thick), Vector3(half_len, y_mid, -half_w_thick))
	_add_quad_direct(st, transform, Vector3(half_len, y_mid, -half_w_thick), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_top, -half_w_thin), Vector3(half_len, y_top, -half_w_thin))
	_add_polygon_6(st, transform, Vector3(half_len, y_bot, -half_w_thick), Vector3(half_len, y_mid, -half_w_thick), Vector3(half_len, y_top, -half_w_thin), Vector3(half_len, y_top, half_w_thin), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_bot, half_w_thick))
	_add_polygon_6(st, transform, Vector3(-half_len, y_bot, half_w_thick), Vector3(-half_len, y_mid, half_w_thick), Vector3(-half_len, y_top, half_w_thin), Vector3(-half_len, y_top, -half_w_thin), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_bot, -half_w_thick))

static func _append_top_cornice(
	st: SurfaceTool, length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D
) -> void:
	var h_slope: float = clampf(slope_height, 0.02, total_height * 0.45)
	var h_main: float = total_height - h_slope
	var w_thin: float = wall_thickness
	var w_thick: float = wall_thickness + (trim_overhang * 2.0)
	var half_len: float = length * 0.5
	var half_w_thick: float = w_thick * 0.5
	var half_w_thin: float = w_thin * 0.5
	var half_h: float = total_height * 0.5

	var y_top: float = half_h
	var y_mid: float = half_h - h_main
	var y_bot: float = -half_h

	_add_quad_direct(st, transform, Vector3(-half_len, y_top, half_w_thick), Vector3(half_len, y_top, half_w_thick), Vector3(half_len, y_top, -half_w_thick), Vector3(-half_len, y_top, -half_w_thick))
	_add_quad_direct(st, transform, Vector3(-half_len, y_mid, half_w_thick), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_top, half_w_thick), Vector3(-half_len, y_top, half_w_thick))
	_add_quad_direct(st, transform, Vector3(-half_len, y_bot, half_w_thin), Vector3(half_len, y_bot, half_w_thin), Vector3(half_len, y_mid, half_w_thick), Vector3(-half_len, y_mid, half_w_thick))
	_add_quad_direct(st, transform, Vector3(half_len, y_mid, -half_w_thick), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_top, -half_w_thick), Vector3(half_len, y_top, -half_w_thick))
	_add_quad_direct(st, transform, Vector3(half_len, y_bot, -half_w_thin), Vector3(-half_len, y_bot, -half_w_thin), Vector3(-half_len, y_mid, -half_w_thick), Vector3(half_len, y_mid, -half_w_thick))
	_add_polygon_6(st, transform, Vector3(half_len, y_bot, -half_w_thin), Vector3(half_len, y_mid, -half_w_thick), Vector3(half_len, y_top, -half_w_thick), Vector3(half_len, y_top, half_w_thick), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_bot, half_w_thin))
	_add_polygon_6(st, transform, Vector3(-half_len, y_bot, half_w_thin), Vector3(-half_len, y_mid, half_w_thick), Vector3(-half_len, y_top, half_w_thick), Vector3(-half_len, y_top, -half_w_thick), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_bot, -half_w_thin))

static func _append_arch_wall_panel(
	st: SurfaceTool, total_width: float, panel_height: float, wall_thickness: float,
	opening_width: float, opening_height: float, _inner_bevel: float, transform: Transform3D
) -> void:
	var half_w: float = total_width * 0.5
	var half_open_w: float = opening_width * 0.5
	var half_t: float = wall_thickness * 0.5

	var radius: float = half_open_w
	var spring_y: float = clampf(opening_height - radius, 0.2, panel_height - radius - 0.05)

	var num_segs: int = 16
	var curve_pts: Array[Vector2] = []

	for s in range(num_segs + 1):
		var angle: float = PI - (float(s) / float(num_segs) * PI)
		var cx: float = cos(angle) * radius
		var cy: float = spring_y + (sin(angle) * radius)
		curve_pts.append(Vector2(cx, cy))

	# Cara Frontal (+Z)
	_add_quad_direct(st, transform, Vector3(-half_w, 0.0, half_t), Vector3(-half_open_w, 0.0, half_t), Vector3(-half_open_w, spring_y, half_t), Vector3(-half_w, spring_y, half_t))
	_add_quad_direct(st, transform, Vector3(-half_w, spring_y, half_t), Vector3(-half_open_w, spring_y, half_t), Vector3(-half_open_w, panel_height, half_t), Vector3(-half_w, panel_height, half_t))
	_add_quad_direct(st, transform, Vector3(half_open_w, 0.0, half_t), Vector3(half_w, 0.0, half_t), Vector3(half_w, spring_y, half_t), Vector3(half_open_w, spring_y, half_t))
	_add_quad_direct(st, transform, Vector3(half_open_w, spring_y, half_t), Vector3(half_w, spring_y, half_t), Vector3(half_w, panel_height, half_t), Vector3(half_open_w, panel_height, half_t))

	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]
		_add_quad_direct(st, transform, Vector3(p0.x, p0.y, half_t), Vector3(p1.x, p1.y, half_t), Vector3(p1.x, panel_height, half_t), Vector3(p0.x, panel_height, half_t))

	# Cara Trasera (-Z)
	_add_quad_direct(st, transform, Vector3(-half_open_w, 0.0, -half_t), Vector3(-half_w, 0.0, -half_t), Vector3(-half_w, spring_y, -half_t), Vector3(-half_open_w, spring_y, -half_t))
	_add_quad_direct(st, transform, Vector3(-half_open_w, spring_y, -half_t), Vector3(-half_w, spring_y, -half_t), Vector3(-half_w, panel_height, -half_t), Vector3(-half_open_w, panel_height, -half_t))
	_add_quad_direct(st, transform, Vector3(half_w, 0.0, -half_t), Vector3(half_open_w, 0.0, -half_t), Vector3(half_open_w, spring_y, -half_t), Vector3(half_w, spring_y, -half_t))
	_add_quad_direct(st, transform, Vector3(half_w, spring_y, -half_t), Vector3(half_open_w, spring_y, -half_t), Vector3(half_open_w, panel_height, -half_t), Vector3(half_w, panel_height, -half_t))

	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]
		_add_quad_direct(st, transform, Vector3(p1.x, p1.y, -half_t), Vector3(p0.x, p0.y, -half_t), Vector3(p0.x, panel_height, -half_t), Vector3(p1.x, panel_height, -half_t))

	# Intradós del Arco (Bóveda y Jambas)
	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]
		_add_quad_direct(st, transform, Vector3(p0.x, p0.y, half_t), Vector3(p0.x, p0.y, -half_t), Vector3(p1.x, p1.y, -half_t), Vector3(p1.x, p1.y, half_t))

	_add_quad_direct(st, transform, Vector3(-half_open_w, 0.0, half_t), Vector3(-half_open_w, 0.0, -half_t), Vector3(-half_open_w, spring_y, -half_t), Vector3(-half_open_w, spring_y, half_t))
	_add_quad_direct(st, transform, Vector3(half_open_w, 0.0, -half_t), Vector3(half_open_w, 0.0, half_t), Vector3(half_open_w, spring_y, half_t), Vector3(half_open_w, spring_y, -half_t))

	# Caras Exteriores (-X y +X)
	_add_quad_direct(st, transform, Vector3(-half_w, 0.0, -half_t), Vector3(-half_w, 0.0, half_t), Vector3(-half_w, panel_height, half_t), Vector3(-half_w, panel_height, -half_t))
	_add_quad_direct(st, transform, Vector3(half_w, 0.0, half_t), Vector3(half_w, 0.0, -half_t), Vector3(half_w, panel_height, -half_t), Vector3(half_w, panel_height, half_t))

static func _append_pillowed_brick(st: SurfaceTool, size: Vector3, transform: Transform3D, bevel: float = 0.028) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var b: float = clampf(bevel, 0.001, minf(hx, minf(hy, hz)) * 0.45)
	var ix: float = hx - b
	var iy: float = hy - b
	var iz: float = hz - b

	_add_quad_direct(st, transform, Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz), Vector3(ix, iy, hz), Vector3(-ix, iy, hz))
	_add_quad_direct(st, transform, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz))
	_add_quad_direct(st, transform, Vector3(hx, -iy, iz), Vector3(hx, -iy, -iz), Vector3(hx, iy, -iz), Vector3(hx, iy, iz))
	_add_quad_direct(st, transform, Vector3(-hx, -iy, -iz), Vector3(-hx, -iy, iz), Vector3(-hx, iy, iz), Vector3(-hx, iy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, hy, iz), Vector3(ix, hy, iz), Vector3(ix, hy, -iz), Vector3(-ix, hy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz), Vector3(ix, -hy, iz), Vector3(-ix, -hy, iz))

	_add_quad_direct(st, transform, Vector3(-ix, iy, hz), Vector3(ix, iy, hz), Vector3(ix, hy, iz), Vector3(-ix, hy, iz))
	_add_quad_direct(st, transform, Vector3(-ix, -hy, iz), Vector3(ix, -hy, iz), Vector3(ix, -iy, hz), Vector3(-ix, -iy, hz))
	_add_quad_direct(st, transform, Vector3(-ix, hy, -iz), Vector3(ix, hy, -iz), Vector3(ix, iy, -hz), Vector3(-ix, iy, -hz))
	_add_quad_direct(st, transform, Vector3(ix, -hy, -iz), Vector3(-ix, -hy, -iz), Vector3(-ix, -iy, -hz), Vector3(ix, -iy, -hz))

	_add_quad_direct(st, transform, Vector3(ix, -iy, hz), Vector3(hx, -iy, iz), Vector3(hx, iy, iz), Vector3(ix, iy, hz))
	_add_quad_direct(st, transform, Vector3(-hx, -iy, iz), Vector3(-ix, -iy, hz), Vector3(-ix, iy, hz), Vector3(-hx, iy, iz))
	_add_quad_direct(st, transform, Vector3(hx, -iy, -iz), Vector3(ix, -iy, -hz), Vector3(ix, iy, -hz), Vector3(hx, iy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, -iy, -hz), Vector3(-hx, -iy, -iz), Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz))

	_add_quad_direct(st, transform, Vector3(ix, hy, iz), Vector3(hx, iy, iz), Vector3(hx, iy, -iz), Vector3(ix, hy, -iz))
	_add_quad_direct(st, transform, Vector3(hx, -iy, iz), Vector3(ix, -hy, iz), Vector3(ix, -hy, -iz), Vector3(hx, -iy, -iz))
	_add_quad_direct(st, transform, Vector3(-hx, iy, iz), Vector3(-ix, hy, iz), Vector3(-ix, hy, -iz), Vector3(-hx, iy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, -hy, iz), Vector3(-hx, -iy, iz), Vector3(-hx, -iy, -iz), Vector3(-ix, -hy, -iz))

static func _add_polygon_6(st: SurfaceTool, transform: Transform3D, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, v5: Vector3) -> void:
	_add_triangle_direct(st, transform, v0, v1, v2)
	_add_triangle_direct(st, transform, v0, v2, v3)
	_add_triangle_direct(st, transform, v0, v3, v4)
	_add_triangle_direct(st, transform, v0, v4, v5)

static func _add_quad_direct(st: SurfaceTool, transform: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle_direct(st, transform, p0, p1, p2)
	_add_triangle_direct(st, transform, p0, p2, p3)

static func _add_triangle_direct(st: SurfaceTool, transform: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var w0: Vector3 = transform * p0
	var w1: Vector3 = transform * p1
	var w2: Vector3 = transform * p2
	var normal: Vector3 = (w1 - w0).cross(w2 - w0).normalized()

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(w0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(w1)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(w2)
