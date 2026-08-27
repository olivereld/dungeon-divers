class_name WallGeometryBuilder
extends RefCounted

## Extrusor de geometría poligonal continua para muros de mazmorra (Fase M2 & Hardening).
## Genera mallas limpias (ArrayMesh) a nivel de WallComponent y a nivel de WallSection discreto,
## con uniones en inglete (miter joints) matemáticamente robustas y libres de NaNs o caras degeneradas.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")

func build_section_mesh(
	section: _WallSectionScript,
	config: _WallGeometryConfigScript = null
) -> _GeneratedMeshScript:
	var g_mesh := _GeneratedMeshScript.new()
	if section == null or section.points.size() < 2:
		return g_mesh

	if config == null:
		config = _WallGeometryConfigScript.new()

	g_mesh.component_id = section.component_id
	g_mesh.section_id = section.id
	g_mesh.room_id = section.room_id
	g_mesh.variant_id = section.variant_id

	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()

	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_h: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()
	var bot_trim_h: float = config.bottom_trim_height
	var top_trim_h: float = config.top_trim_height
	var bot_slope_h: float = config.bottom_trim_slope_height
	var top_slope_h: float = config.top_trim_slope_height

	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)
	var tile_size: float = config.cube_size

	var bounds_init: bool = false
	var aabb := AABB()

	var pts_3d: Array[Vector3] = []
	for pt in section.points:
		var p3 := Vector3(float(pt.x) * tile_size, 0.0, float(pt.y) * tile_size)
		pts_3d.append(p3)
		if not bounds_init:
			aabb = AABB(p3, Vector3(0.01, total_h, 0.01))
			bounds_init = true
		else:
			aabb = aabb.expand(p3)
			aabb = aabb.expand(p3 + Vector3(0.0, total_h, 0.0))

	var n: int = pts_3d.size()
	var is_closed: bool = section.is_closed_loop and (n >= 3) and (section.points[0] == section.points[n - 1])

	var miter_dirs: Array[Vector3] = []
	for i in range(n):
		var miter := Vector3.ZERO
		if is_closed:
			var prev_pt: Vector3 = pts_3d[(i - 1 + n) % n]
			var curr_pt: Vector3 = pts_3d[i]
			var next_pt: Vector3 = pts_3d[(i + 1) % n]
			var diff_in: Vector3 = curr_pt - prev_pt
			var diff_out: Vector3 = next_pt - curr_pt
			var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
			var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD
			var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
			var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)
			miter = n_wall_in + n_wall_out
			if miter.length_squared() < 0.0001:
				miter = n_wall_in
			else:
				var m_dir: Vector3 = miter.normalized()
				var dot: float = n_wall_in.dot(m_dir)
				var m_scale: float = 1.0 / maxf(dot, 0.001)
				miter = m_dir * clampf(m_scale, 0.5, config.max_miter_scale)
		else:
			if i == 0:
				if section.start_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
					var prev_pt := Vector3(float(section.start_miter_neighbor.x) * tile_size, 0.0, float(section.start_miter_neighbor.y) * tile_size)
					var diff_in: Vector3 = pts_3d[0] - prev_pt
					var diff_out: Vector3 = pts_3d[1] - pts_3d[0]
					var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
					var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD
					var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
					var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)
					miter = n_wall_in + n_wall_out
					if miter.length_squared() < 0.0001:
						miter = n_wall_in
					else:
						var m_dir: Vector3 = miter.normalized()
						var dot: float = n_wall_in.dot(m_dir)
						var m_scale: float = 1.0 / maxf(dot, 0.001)
						miter = m_dir * clampf(m_scale, 0.5, config.max_miter_scale)
				else:
					var diff_out: Vector3 = pts_3d[1] - pts_3d[0]
					var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD
					miter = Vector3(t_out.z, 0.0, -t_out.x)
			elif i == n - 1:
				if section.end_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
					var next_pt := Vector3(float(section.end_miter_neighbor.x) * tile_size, 0.0, float(section.end_miter_neighbor.y) * tile_size)
					var diff_in: Vector3 = pts_3d[n - 1] - pts_3d[n - 2]
					var diff_out: Vector3 = next_pt - pts_3d[n - 1]
					var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
					var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD
					var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
					var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)
					miter = n_wall_in + n_wall_out
					if miter.length_squared() < 0.0001:
						miter = n_wall_in
					else:
						var m_dir: Vector3 = miter.normalized()
						var dot: float = n_wall_in.dot(m_dir)
						var m_scale: float = 1.0 / maxf(dot, 0.001)
						miter = m_dir * clampf(m_scale, 0.5, config.max_miter_scale)
				else:
					var diff_in: Vector3 = pts_3d[n - 1] - pts_3d[n - 2]
					var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
					miter = Vector3(t_in.z, 0.0, -t_in.x)
			else:
				var diff_in: Vector3 = pts_3d[i] - pts_3d[i - 1]
				var diff_out: Vector3 = pts_3d[i + 1] - pts_3d[i]
				var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
				var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD
				var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
				var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)
				miter = n_wall_in + n_wall_out
				if miter.length_squared() < 0.0001:
					miter = n_wall_in
				else:
					var m_dir: Vector3 = miter.normalized()
					var dot: float = n_wall_in.dot(m_dir)
					var m_scale: float = 1.0 / maxf(dot, 0.001)
					miter = m_dir * clampf(m_scale, 0.5, config.max_miter_scale)
		miter_dirs.append(miter)

	var segment_count: int = n if is_closed else (n - 1)
	for i in range(segment_count):
		var next_i: int = (i + 1) % n
		var p0: Vector3 = pts_3d[i]
		var p1: Vector3 = pts_3d[next_i]
		var m0: Vector3 = miter_dirs[i]
		var m1: Vector3 = miter_dirs[next_i]

		_extrude_wall_segment(
			st_trims, st_panel, p0, p1, m0, m1,
			w_thick, w_thin, d, total_h, panel_h,
			bot_trim_h, top_trim_h, bot_slope_h, top_slope_h
		)

	# Tapas extremas solo para tramos realmente abiertos (terminaciones)
	if section.has_start_cap and n >= 2:
		var p_start = pts_3d[0]
		var m_start = miter_dirs[0]
		_add_quad(st_trims,
			p_start,
			p_start + m_start * w_thick,
			p_start + m_start * w_thick + Vector3(0, total_h, 0),
			p_start + Vector3(0, total_h, 0)
		)

	if section.has_end_cap and n >= 2:
		var p_end = pts_3d[n - 1]
		var m_end = miter_dirs[n - 1]
		_add_quad(st_trims,
			p_end + m_end * w_thick,
			p_end,
			p_end + Vector3(0, total_h, 0),
			p_end + m_end * w_thick + Vector3(0, total_h, 0)
		)

	var mesh := ArrayMesh.new()
	st_trims.generate_normals()
	st_trims.index()
	st_trims.generate_tangents()
	mesh = st_trims.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_name(0, "Trims")

	st_panel.generate_normals()
	st_panel.index()
	st_panel.generate_tangents()
	mesh = st_panel.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_name(1, "WallPanel")

	g_mesh.mesh = mesh
	g_mesh.bounds = aabb
	return g_mesh

func build_component_mesh(
	component: _WallComponentScript,
	config: _WallGeometryConfigScript = null
) -> _GeneratedMeshScript:
	var g_mesh := _GeneratedMeshScript.new()
	if component == null or component.is_empty():
		return g_mesh

	if config == null:
		config = _WallGeometryConfigScript.new()

	g_mesh.component_id = component.id

	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()

	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_h: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()
	var bot_trim_h: float = config.bottom_trim_height
	var top_trim_h: float = config.top_trim_height
	var bot_slope_h: float = config.bottom_trim_slope_height
	var top_slope_h: float = config.top_trim_slope_height

	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)
	var tile_size: float = config.cube_size

	var bounds_init: bool = false
	var aabb := AABB()

	# Procesar cada bucle cerrado del componente
	for loop_raw in component.loops:
		var loop_points: Array[Vector2i] = []
		for pt_raw in loop_raw:
			var pt_vec: Vector2i = pt_raw as Vector2i
			if loop_points.is_empty() or loop_points[loop_points.size() - 1] != pt_vec:
				loop_points.append(pt_vec)

		if loop_points.size() > 1 and loop_points[0] == loop_points[loop_points.size() - 1]:
			loop_points.pop_back()

		var n: int = loop_points.size()
		if n < 3:
			continue

		var pts_3d: Array[Vector3] = []
		for pt in loop_points:
			var p3 := Vector3(float(pt.x) * tile_size, 0.0, float(pt.y) * tile_size)
			pts_3d.append(p3)
			if not bounds_init:
				aabb = AABB(p3, Vector3(0.01, total_h, 0.01))
				bounds_init = true
			else:
				aabb = aabb.expand(p3)
				aabb = aabb.expand(p3 + Vector3(0.0, total_h, 0.0))

		var miter_dirs: Array[Vector3] = []
		for i in range(n):
			var prev_pt: Vector3 = pts_3d[(i - 1 + n) % n]
			var curr_pt: Vector3 = pts_3d[i]
			var next_pt: Vector3 = pts_3d[(i + 1) % n]

			var diff_in: Vector3 = curr_pt - prev_pt
			var diff_out: Vector3 = next_pt - curr_pt

			var t_in: Vector3 = diff_in.normalized() if diff_in.length_squared() > 0.0001 else Vector3.FORWARD
			var t_out: Vector3 = diff_out.normalized() if diff_out.length_squared() > 0.0001 else Vector3.FORWARD

			var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
			var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)

			var miter: Vector3 = n_wall_in + n_wall_out
			if miter.length_squared() < 0.0001:
				miter = n_wall_in
			else:
				var m_dir: Vector3 = miter.normalized()
				var dot: float = n_wall_in.dot(m_dir)
				var m_scale: float = 1.0 / maxf(dot, 0.001)
				m_scale = clampf(m_scale, 0.5, config.max_miter_scale)
				miter = m_dir * m_scale

			miter_dirs.append(miter)

		for i in range(n):
			var next_i: int = (i + 1) % n
			var p0: Vector3 = pts_3d[i]
			var p1: Vector3 = pts_3d[next_i]
			var m0: Vector3 = miter_dirs[i]
			var m1: Vector3 = miter_dirs[next_i]

			_extrude_wall_segment(
				st_trims, st_panel, p0, p1, m0, m1,
				w_thick, w_thin, d, total_h, panel_h,
				bot_trim_h, top_trim_h, bot_slope_h, top_slope_h
			)

	var mesh := ArrayMesh.new()
	st_trims.generate_normals()
	st_trims.index()
	st_trims.generate_tangents()
	mesh = st_trims.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_name(0, "Trims")

	st_panel.generate_normals()
	st_panel.index()
	st_panel.generate_tangents()
	mesh = st_panel.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_name(1, "WallPanel")

	g_mesh.mesh = mesh
	g_mesh.bounds = aabb
	return g_mesh

static func _extrude_wall_segment(
	st_trims: SurfaceTool,
	st_panel: SurfaceTool,
	p0: Vector3,
	p1: Vector3,
	m0: Vector3,
	m1: Vector3,
	w_thick: float,
	w_thin: float,
	d: float,
	total_h: float,
	panel_h: float,
	bot_trim_h: float,
	top_trim_h: float,
	bot_slope_h: float,
	top_slope_h: float
) -> void:
	var p0_inner_thick: Vector3 = p0
	var p1_inner_thick: Vector3 = p1

	var p0_inner_thin: Vector3 = p0 + (m0 * (d * 0.5))
	var p1_inner_thin: Vector3 = p1 + (m1 * (d * 0.5))

	var p0_outer_thick: Vector3 = p0 + (m0 * w_thick)
	var p1_outer_thick: Vector3 = p1 + (m1 * w_thick)

	var p0_outer_thin: Vector3 = p0 + (m0 * (w_thick - d * 0.5))
	var p1_outer_thin: Vector3 = p1 + (m1 * (w_thick - d * 0.5))

	# --- ZÓCALO INFERIOR (TRIMS) ---
	var y_bot_base: float = 0.0
	var y_mid_base: float = bot_trim_h - bot_slope_h
	var y_top_base: float = bot_trim_h

	# Cara frontal vertical inferior
	_add_quad(st_trims,
		Vector3(p0_inner_thick.x, y_bot_base, p0_inner_thick.z),
		Vector3(p1_inner_thick.x, y_bot_base, p1_inner_thick.z),
		Vector3(p1_inner_thick.x, y_mid_base, p1_inner_thick.z),
		Vector3(p0_inner_thick.x, y_mid_base, p0_inner_thick.z)
	)
	# Pendiente frontal a 45° superior
	_add_quad(st_trims,
		Vector3(p0_inner_thick.x, y_mid_base, p0_inner_thick.z),
		Vector3(p1_inner_thick.x, y_mid_base, p1_inner_thick.z),
		Vector3(p1_inner_thin.x, y_top_base, p1_inner_thin.z),
		Vector3(p0_inner_thin.x, y_top_base, p0_inner_thin.z)
	)
	# Cara trasera exterior zócalo
	_add_quad(st_trims,
		Vector3(p1_outer_thick.x, y_bot_base, p1_outer_thick.z),
		Vector3(p0_outer_thick.x, y_bot_base, p0_outer_thick.z),
		Vector3(p0_outer_thick.x, y_mid_base, p0_outer_thick.z),
		Vector3(p1_outer_thick.x, y_mid_base, p1_outer_thick.z)
	)
	# Pendiente trasera exterior a 45°
	_add_quad(st_trims,
		Vector3(p1_outer_thick.x, y_mid_base, p1_outer_thick.z),
		Vector3(p0_outer_thick.x, y_mid_base, p0_outer_thick.z),
		Vector3(p0_outer_thin.x, y_top_base, p0_outer_thin.z),
		Vector3(p1_outer_thin.x, y_top_base, p1_outer_thin.z)
	)

	# --- PANEL CENTRAL DE PARED (WALLPANEL) ---
	var y_bot_panel: float = bot_trim_h
	var y_top_panel: float = total_h - top_trim_h

	# Cara frontal del panel
	_add_quad(st_panel,
		Vector3(p0_inner_thin.x, y_bot_panel, p0_inner_thin.z),
		Vector3(p1_inner_thin.x, y_bot_panel, p1_inner_thin.z),
		Vector3(p1_inner_thin.x, y_top_panel, p1_inner_thin.z),
		Vector3(p0_inner_thin.x, y_top_panel, p0_inner_thin.z)
	)
	# Cara trasera del panel
	_add_quad(st_panel,
		Vector3(p1_outer_thin.x, y_bot_panel, p1_outer_thin.z),
		Vector3(p0_outer_thin.x, y_bot_panel, p0_outer_thin.z),
		Vector3(p0_outer_thin.x, y_top_panel, p0_outer_thin.z),
		Vector3(p1_outer_thin.x, y_top_panel, p1_outer_thin.z)
	)

	# --- CORNISA SUPERIOR (TRIMS) ---
	var y_bot_cornice: float = total_h - top_trim_h
	var y_mid_cornice: float = total_h - top_trim_h + top_slope_h
	var y_top_cornice: float = total_h

	# Pendiente frontal inferior a 45°
	_add_quad(st_trims,
		Vector3(p0_inner_thin.x, y_bot_cornice, p0_inner_thin.z),
		Vector3(p1_inner_thin.x, y_bot_cornice, p1_inner_thin.z),
		Vector3(p1_inner_thick.x, y_mid_cornice, p1_inner_thick.z),
		Vector3(p0_inner_thick.x, y_mid_cornice, p0_inner_thick.z)
	)
	# Cara frontal vertical superior
	_add_quad(st_trims,
		Vector3(p0_inner_thick.x, y_mid_cornice, p0_inner_thick.z),
		Vector3(p1_inner_thick.x, y_mid_cornice, p1_inner_thick.z),
		Vector3(p1_inner_thick.x, y_top_cornice, p1_inner_thick.z),
		Vector3(p0_inner_thick.x, y_top_cornice, p0_inner_thick.z)
	)
	# Tapa superior plana
	_add_quad(st_trims,
		Vector3(p0_inner_thick.x, y_top_cornice, p0_inner_thick.z),
		Vector3(p1_inner_thick.x, y_top_cornice, p1_inner_thick.z),
		Vector3(p1_outer_thick.x, y_top_cornice, p1_outer_thick.z),
		Vector3(p0_outer_thick.x, y_top_cornice, p0_outer_thick.z)
	)
	# Cara trasera vertical superior
	_add_quad(st_trims,
		Vector3(p1_outer_thick.x, y_mid_cornice, p1_outer_thick.z),
		Vector3(p0_outer_thick.x, y_mid_cornice, p0_outer_thick.z),
		Vector3(p0_outer_thick.x, y_top_cornice, p0_outer_thick.z),
		Vector3(p1_outer_thick.x, y_top_cornice, p1_outer_thick.z)
	)
	# Pendiente trasera inferior a 45°
	_add_quad(st_trims,
		Vector3(p1_outer_thin.x, y_bot_cornice, p1_outer_thin.z),
		Vector3(p0_outer_thin.x, y_bot_cornice, p0_outer_thin.z),
		Vector3(p0_outer_thick.x, y_mid_cornice, p0_outer_thick.z),
		Vector3(p1_outer_thick.x, y_mid_cornice, p1_outer_thick.z)
	)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var cross1: Vector3 = (p1 - p0).cross(p2 - p0)
	if cross1.length_squared() >= 0.000001:
		var normal1: Vector3 = cross1.normalized()
		st.set_normal(normal1)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)

		st.set_normal(normal1)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p1)

		st.set_normal(normal1)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)

	var cross2: Vector3 = (p2 - p0).cross(p3 - p0)
	if cross2.length_squared() >= 0.000001:
		var normal2: Vector3 = cross2.normalized()
		st.set_normal(normal2)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)

		st.set_normal(normal2)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)

		st.set_normal(normal2)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p3)
