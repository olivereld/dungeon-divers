class_name WallGeometryBuilder
extends RefCounted

## Extrusor de geometría poligonal continua para muros de mazmorra (Fase M2 & Hardening).
## Genera mallas limpias (ArrayMesh) a nivel de WallComponent y a nivel de WallSection discreto,
## con uniones en inglete (miter joints) matemáticamente deterministas, calculadas una sola vez
## mediante WallCornerResolver y compartidas por todos los perfiles a través de WallPathGeometry.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _WallCornerResolverScript = preload("res://src/geometry_generator/geometry/wall_corner_resolver.gd")
const _WallPathGeometryScript = preload("res://src/geometry_generator/geometry/wall_path_geometry.gd")

var _corner_resolver: _WallCornerResolverScript

func _init() -> void:
	_corner_resolver = _WallCornerResolverScript.new()

## Construye la malla para una sección discreta (WallSection) consumiendo WallPathGeometry.
func build_section_mesh(
	section: _WallSectionScript,
	config: _WallGeometryConfigScript = null
) -> _GeneratedMeshScript:
	if section == null or section.points.size() < 2:
		return _GeneratedMeshScript.new()

	if config == null:
		config = _WallGeometryConfigScript.new()

	var path_geom: _WallPathGeometryScript = _WallPathGeometryScript.from_section(
		section, config, _corner_resolver
	)
	if path_geom == null or path_geom.get_segment_count() == 0:
		return _GeneratedMeshScript.new()

	return _build_mesh_from_paths([path_geom], config, path_geom.metadata)

## Construye la malla para un WallComponent completo consumiendo WallPathGeometry para cada loop y chain.
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

	var path_geometries: Array = []
	for loop in component.loops:
		var pg = _WallPathGeometryScript.from_component_loop(
			loop, component.id, config, _corner_resolver
		)
		if pg != null and pg.get_segment_count() > 0:
			path_geometries.append(pg)

	for chain in component.open_chains:
		var pg = _WallPathGeometryScript.from_component_chain(
			chain, component.id, config, _corner_resolver
		)
		if pg != null and pg.get_segment_count() > 0:
			path_geometries.append(pg)

	if path_geometries.is_empty():
		return g_mesh

	var meta := {"component_id": component.id}
	return _build_mesh_from_paths(path_geometries, config, meta)

## Núcleo unificado de extrusión de malla a partir de uno o más recorridos WallPathGeometry.
func _build_mesh_from_paths(
	path_geometries: Array,
	config: _WallGeometryConfigScript,
	metadata: Dictionary = {}
) -> _GeneratedMeshScript:
	var g_mesh := _GeneratedMeshScript.new()
	if metadata.has("component_id"):
		g_mesh.component_id = metadata["component_id"]
	if metadata.has("section_id"):
		g_mesh.section_id = metadata["section_id"]
	if metadata.has("room_id"):
		g_mesh.room_id = metadata["room_id"]
	if metadata.has("variant_id"):
		g_mesh.variant_id = metadata["variant_id"]

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

	var bounds_init: bool = false
	var aabb := AABB()

	for path_geom_val in path_geometries:
		var path_geom = path_geom_val as _WallPathGeometryScript
		if path_geom == null:
			continue

		if not bounds_init:
			aabb = path_geom.aabb
			bounds_init = true
		else:
			aabb = aabb.merge(path_geom.aabb)

		var seg_count: int = path_geom.get_segment_count()
		var corner_count: int = path_geom.corners.size()

		for i in range(seg_count):
			var next_i: int = (i + 1) % corner_count
			var c0 = path_geom.corners[i]
			var c1 = path_geom.corners[next_i]

			if c0.point.distance_squared_to(c1.point) < 0.0001:
				continue

			_extrude_wall_segment(
				st_trims, st_panel, c0, c1,
				total_h, panel_h,
				bot_trim_h, top_trim_h, bot_slope_h, top_slope_h
			)

		# Tapas extremas solo para terminaciones abiertas reales
		if path_geom.has_start_cap and corner_count >= 2:
			var c_start = path_geom.corners[0]
			_add_quad(st_trims,
				c_start.inner_thick,
				c_start.outer_thick,
				c_start.outer_thick + Vector3(0.0, total_h, 0.0),
				c_start.inner_thick + Vector3(0.0, total_h, 0.0)
			)

		if path_geom.has_end_cap and corner_count >= 2:
			var c_end = path_geom.corners[corner_count - 1]
			_add_quad(st_trims,
				c_end.outer_thick,
				c_end.inner_thick,
				c_end.inner_thick + Vector3(0.0, total_h, 0.0),
				c_end.outer_thick + Vector3(0.0, total_h, 0.0)
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

## Extruye un segmento individual de muro consumiendo los puntos de perfil resueltos de c0 y c1.
static func _extrude_wall_segment(
	st_trims: SurfaceTool,
	st_panel: SurfaceTool,
	c0, # CornerSolution
	c1, # CornerSolution
	total_h: float,
	panel_h: float,
	bot_trim_h: float,
	top_trim_h: float,
	bot_slope_h: float,
	top_slope_h: float
) -> void:
	var p0_inner_thick: Vector3 = c0.inner_thick
	var p1_inner_thick: Vector3 = c1.inner_thick

	var p0_inner_thin: Vector3 = c0.inner_thin
	var p1_inner_thin: Vector3 = c1.inner_thin

	var p0_outer_thick: Vector3 = c0.outer_thick
	var p1_outer_thick: Vector3 = c1.outer_thick

	var p0_outer_thin: Vector3 = c0.outer_thin
	var p1_outer_thin: Vector3 = c1.outer_thin

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

## Calcula la dirección y escala de inglete (miter) continua para compatibilidad con código legado.
static func _calculate_miter(t_in: Vector3, t_out: Vector3, max_scale: float = 4.0) -> Vector3:
	var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
	var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)
	var dot_n: float = n_wall_in.dot(n_wall_out)
	var denom: float = 1.0 + dot_n
	if denom > 0.0001:
		var miter := (n_wall_in + n_wall_out) / denom
		if miter.length() > max_scale:
			return miter.normalized() * max_scale
		return miter
	return n_wall_in
