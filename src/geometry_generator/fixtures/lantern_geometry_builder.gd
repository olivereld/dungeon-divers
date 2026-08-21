class_name LanternGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de estilo low-poly para Faroles Góticos (Hanging Lantern y Wall Lantern).
## Soporta:
## 1. Farol Colgante (Hanging): Anilla hexagonal superior de suspensión.
## 2. Farol de Pared (Wall-Mounted): Remate en aguja superior, placa de anclaje a pared en -Z,
##    asiento cónico sólido, brazo horizontal volumétrico con espigón frontal y ménsula inferior en voluta 3D sólida.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_lantern_fixture(config = null):
	if config == null:
		config = _LanternGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"gothic_wall_lantern" if config.is_wall_mounted else &"gothic_hanging_lantern"

	var s: float = config.scale_mult
	var num_sides: int = maxi(4, config.num_sides)
	var angles: Array[float] = []
	for i in range(num_sides):
		angles.append(float(i) * (TAU / float(num_sides)))

	# ==========================================================================
	# 1. ESTRUCTURA Y MARCO DE HIERRO / METAL OSCURO (LANTERN FRAME & BRACKET)
	# ==========================================================================
	var g_frame = _GeneratedMeshScript.new()
	g_frame.component_id = 0
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. CÚPULA ACAMPANADA (BELL ROOF & CORNICE) ---
	var y_roof_top: float = 0.32 * s
	var y_roof_mid: float = 0.22 * s
	var y_roof_eave: float = 0.12 * s
	var y_roof_bot: float = 0.08 * s

	var r_roof_top: float = 0.045 * s
	var r_roof_mid: float = 0.11 * s
	var r_roof_eave: float = 0.21 * s
	var r_cage: float = 0.17 * s

	# Tapa superior del tejado
	_build_ngon_cap(st_frame, y_roof_top, r_roof_top, angles, true)
	# Curva acampanada superior
	_build_ngon_frustum(st_frame, y_roof_mid, y_roof_top, r_roof_mid, r_roof_top, angles)
	# Curva acampanada media hacia el alero
	_build_ngon_frustum(st_frame, y_roof_eave, y_roof_mid, r_roof_eave, r_roof_mid, angles)
	# Bisel inferior del alero hacia el cuerpo de la jaula
	_build_ngon_frustum(st_frame, y_roof_bot, y_roof_eave, r_cage, r_roof_eave, angles)

	# --- B. REMATE SUPERIOR (COLGANTE VS AGUJA DE PARED) ---
	if not config.is_wall_mounted:
		# Anilla de suspensión hexagonal
		var y_stem_bot: float = y_roof_top
		var y_stem_top: float = y_roof_top + 0.035 * s
		var r_stem: float = 0.016 * s
		_build_ngon_frustum(st_frame, y_stem_bot, y_stem_top, r_stem, r_stem, angles)

		var y_ring_center: float = y_stem_top + 0.065 * s
		var r_ring_out: float = 0.055 * s
		var r_ring_in: float = 0.035 * s
		var ring_thick: float = 0.018 * s
		_build_vertical_hex_ring(st_frame, y_ring_center, r_ring_out, r_ring_in, ring_thick)
	else:
		# Remate en aguja torneada gótica (Finial Spire)
		_build_spire_finial(st_frame, y_roof_top, r_roof_top, angles, s)

	# --- C. BASE INFERIOR ESCALONADA (BOTTOM BASE) ---
	var y_cage_bot: float = -0.26 * s
	var y_base_mid: float = -0.31 * s
	var y_base_bot: float = -0.34 * s

	var r_base_eave: float = 0.205 * s
	var r_base_bot: float = 0.19 * s

	# Moldura de transición inferior
	_build_ngon_frustum(st_frame, y_base_mid, y_cage_bot, r_base_eave, r_cage, angles)
	# Borde inferior
	_build_ngon_frustum(st_frame, y_base_bot, y_base_mid, r_base_bot, r_base_eave, angles)
	# Tapa de fondo
	_build_ngon_cap(st_frame, y_base_bot, r_base_bot, angles, false)

	# --- D. POSTES Y ARCOS GÓTICOS DE LA JAULA (WINDOW FRAMES & LATTICE) ---
	var pillar_w: float = 0.026 * s
	var arch_h_top: float = 0.065 * s
	var arch_h_bot: float = 0.065 * s

	# 1. Postes esquineros
	for angle in angles:
		var p_top := Vector3(cos(angle) * r_cage, y_roof_bot, sin(angle) * r_cage)
		var p_bot := Vector3(cos(angle) * r_cage, y_cage_bot, sin(angle) * r_cage)
		_build_corner_pillar(st_frame, p_top, p_bot, pillar_w)

	# 2. Arcos ojivales superior e inferior en cada una de las caras
	for i in range(num_sides):
		var i_next: int = (i + 1) % num_sides
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var v_top0 := Vector3(cos(a0) * r_cage, y_roof_bot, sin(a0) * r_cage)
		var v_top1 := Vector3(cos(a1) * r_cage, y_roof_bot, sin(a1) * r_cage)
		var v_bot0 := Vector3(cos(a0) * r_cage, y_cage_bot, sin(a0) * r_cage)
		var v_bot1 := Vector3(cos(a1) * r_cage, y_cage_bot, sin(a1) * r_cage)

		var mid_top := (v_top0 + v_top1) * 0.5
		var mid_bot := (v_bot0 + v_bot1) * 0.5
		var cusp_top := mid_top + Vector3(0.0, -arch_h_top, 0.0)
		var cusp_bot := mid_bot + Vector3(0.0, arch_h_bot, 0.0)

		# Cúspide de arco superior (tímpano apuntado hacia abajo)
		_add_triangle_direct(st_frame, v_top0, v_top1, cusp_top)
		# Cúspide de arco inferior (alfeizar apuntado hacia arriba)
		_add_triangle_direct(st_frame, v_bot1, v_bot0, cusp_bot)

	# --- E. SOPORTE DE PARED INFERIOR VOLUMÉTRICO (WALL BRACKET & SOLID 3D SCROLL) ---
	if config.is_wall_mounted:
		var z_wall: float = -0.28 * s
		_build_wall_bracket_solid(st_frame, y_base_bot, z_wall, angles, s)

	st_frame.generate_tangents()
	var mesh_frame := ArrayMesh.new()
	mesh_frame = st_frame.commit(mesh_frame)
	mesh_frame.surface_set_name(0, "LanternFrame")
	g_frame.mesh = mesh_frame
	g_frame.material_slots[0] = _WallMaterialFactoryScript.create_trim_material()
	asset.add_mesh(&"lantern_frame", g_frame)

	# ==========================================================================
	# 2. NÚCLEO DE CRISTAL TRANSLÚCIDO EMISIVO (LANTERN GLASS CORE)
	# ==========================================================================
	var g_glass = _GeneratedMeshScript.new()
	g_glass.component_id = 1
	var st_glass := SurfaceTool.new()
	st_glass.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r_glass: float = (r_cage * 0.94)
	var y_glass_top: float = (y_roof_bot - 0.005 * s)
	var y_glass_bot: float = (y_cage_bot + 0.005 * s)

	_build_ngon_frustum(st_glass, y_glass_bot, y_glass_top, r_glass, r_glass, angles)
	_build_ngon_cap(st_glass, y_glass_top, r_glass, angles, true)
	_build_ngon_cap(st_glass, y_glass_bot, r_glass, angles, false)

	st_glass.generate_tangents()
	var mesh_glass := ArrayMesh.new()
	mesh_glass = st_glass.commit(mesh_glass)
	mesh_glass.surface_set_name(0, "LanternGlass")
	g_glass.mesh = mesh_glass

	# Material de Cristal Mágico / Vidrio Emisivo
	var mat_glass := StandardMaterial3D.new()
	mat_glass.albedo_color = config.glass_color
	mat_glass.roughness = 0.15
	mat_glass.metallic = 0.1
	mat_glass.emission_enabled = true
	mat_glass.emission = config.glass_color
	mat_glass.emission_energy_multiplier = config.glass_emission_energy
	g_glass.material_slots[0] = mat_glass
	asset.add_mesh(&"lantern_glass", g_glass)

	# ==========================================================================
	# 3. COLISIONES FÍSICAS
	# ==========================================================================
	var col_shape := CylinderShape3D.new()
	col_shape.radius = r_roof_eave * 0.95
	var min_y_col: float = (y_base_bot - 0.30 * s) if config.is_wall_mounted else y_base_bot
	col_shape.height = (y_roof_top - min_y_col)
	g_frame.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, (y_roof_top + min_y_col) * 0.5, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS AUXILIARES
# ==============================================================================

static func _build_spire_finial(st: SurfaceTool, y_base: float, r_base: float, angles: Array[float], s: float) -> void:
	var y1: float = y_base + 0.03 * s
	var y2: float = y_base + 0.07 * s
	var y3: float = y_base + 0.13 * s
	var r_torus: float = r_base * 1.2
	var r_neck: float = r_base * 0.55
	var r_acorn: float = r_base * 0.90

	_build_ngon_frustum(st, y_base, y1, r_base, r_torus, angles)
	_build_ngon_frustum(st, y1, y2, r_torus, r_neck, angles)
	_build_ngon_frustum(st, y2, y3, r_neck, r_acorn, angles)
	_build_ngon_cap(st, y3, r_acorn, angles, true)

static func _build_wall_bracket_solid(st: SurfaceTool, y_lantern_bot: float, z_wall: float, angles: Array[float], s: float) -> void:
	# 1. Asiento / Collarín cónico sólido firmemente conectado a la base del farol
	var y_seat_top: float = y_lantern_bot
	var y_seat_bot: float = y_lantern_bot - 0.04 * s
	var r_seat_top: float = 0.12 * s
	var r_seat_bot: float = 0.06 * s

	_build_ngon_frustum(st, y_seat_bot, y_seat_top, r_seat_bot, r_seat_top, angles)
	_build_ngon_cap(st, y_seat_bot, r_seat_bot, angles, false)

	# 2. Brazo horizontal de hierro forjado (Cantilever Beam)
	var arm_w: float = 0.045 * s
	var arm_h: float = 0.045 * s
	var y_arm_top: float = y_seat_bot
	var y_arm_bot: float = y_seat_bot - arm_h
	var z_front: float = 0.10 * s

	_build_box(st,
		Vector3(-arm_w * 0.5, y_arm_bot, z_wall),
		Vector3(arm_w * 0.5, y_arm_top, z_front)
	)

	# Espigón piramidal frontal decorativo
	var p_tip := Vector3(0.0, (y_arm_top + y_arm_bot) * 0.5, z_front + 0.04 * s)
	var v0 := Vector3(-arm_w * 0.5, y_arm_bot, z_front)
	var v1 := Vector3(arm_w * 0.5, y_arm_bot, z_front)
	var v2 := Vector3(arm_w * 0.5, y_arm_top, z_front)
	var v3 := Vector3(-arm_w * 0.5, y_arm_top, z_front)
	_add_triangle_direct(st, p_tip, v0, v1)
	_add_triangle_direct(st, p_tip, v1, v2)
	_add_triangle_direct(st, p_tip, v2, v3)
	_add_triangle_direct(st, p_tip, v3, v0)

	# 3. Placa / Escudo de pared (Wall Escutcheon Plate con bisel)
	var plate_w: float = 0.12 * s
	var plate_thick: float = 0.02 * s
	var y_plate_top: float = y_arm_top + 0.10 * s
	var y_plate_bot: float = y_arm_bot - 0.22 * s

	_build_box(st,
		Vector3(-plate_w * 0.5, y_plate_bot, z_wall - plate_thick),
		Vector3(plate_w * 0.5, y_plate_top, z_wall)
	)

	# 4. Ménsula en Voluta Sólida 3D (3D Extruded S-Scroll Bar)
	var scroll_w: float = 0.028 * s
	var scroll_h: float = 0.028 * s

	# Curva suavizada de 6 nodos en arco parabólico
	var curve_pts: Array[Vector3] = [
		Vector3(0.0, y_plate_bot + 0.03 * s, z_wall + 0.01 * s),
		Vector3(0.0, y_plate_bot + 0.06 * s, z_wall + 0.06 * s),
		Vector3(0.0, y_plate_bot + 0.11 * s, z_wall + 0.13 * s),
		Vector3(0.0, y_arm_bot - 0.06 * s, z_wall + 0.20 * s),
		Vector3(0.0, y_arm_bot - 0.01 * s, z_wall + 0.26 * s),
		Vector3(0.0, y_arm_bot, 0.0)
	]

	for i in range(curve_pts.size() - 1):
		var p_start: Vector3 = curve_pts[i]
		var p_end: Vector3 = curve_pts[i + 1]
		_build_solid_3d_beam_segment(st, p_start, p_end, scroll_w, scroll_h)

static func _build_solid_3d_beam_segment(st: SurfaceTool, p_start: Vector3, p_end: Vector3, width: float, height: float) -> void:
	var forward: Vector3 = (p_end - p_start).normalized()
	if forward.length_squared() < 0.0001:
		return

	var right := Vector3(1.0, 0.0, 0.0)
	var up := forward.cross(right).normalized()
	if up.length_squared() < 0.0001:
		up = Vector3(0.0, 1.0, 0.0)
		right = up.cross(forward).normalized()

	var h_w: float = width * 0.5
	var h_h: float = height * 0.5

	# 4 esquinas en p_start
	var a0 := p_start - right * h_w - up * h_h
	var a1 := p_start + right * h_w - up * h_h
	var a2 := p_start + right * h_w + up * h_h
	var a3 := p_start - right * h_w + up * h_h

	# 4 esquinas en p_end
	var b0 := p_end - right * h_w - up * h_h
	var b1 := p_end + right * h_w - up * h_h
	var b2 := p_end + right * h_w + up * h_h
	var b3 := p_end - right * h_w + up * h_h

	# 4 caras laterales volumétricas
	_add_quad_direct(st, a0, a1, b1, b0) # Bottom face
	_add_quad_direct(st, a1, a2, b2, b1) # Right face
	_add_quad_direct(st, a2, a3, b3, b2) # Top face
	_add_quad_direct(st, a3, a0, b0, b3) # Left face

static func _build_box(st: SurfaceTool, min_v: Vector3, max_v: Vector3) -> void:
	var p000 := Vector3(min_v.x, min_v.y, min_v.z)
	var p100 := Vector3(max_v.x, min_v.y, min_v.z)
	var p110 := Vector3(max_v.x, max_v.y, min_v.z)
	var p010 := Vector3(min_v.x, max_v.y, min_v.z)

	var p001 := Vector3(min_v.x, min_v.y, max_v.z)
	var p101 := Vector3(max_v.x, min_v.y, max_v.z)
	var p111 := Vector3(max_v.x, max_v.y, max_v.z)
	var p011 := Vector3(min_v.x, max_v.y, max_v.z)

	_add_quad_direct(st, p000, p010, p110, p100) # Front (-Z)
	_add_quad_direct(st, p101, p111, p011, p001) # Back (+Z)
	_add_quad_direct(st, p000, p100, p101, p001) # Bottom (-Y)
	_add_quad_direct(st, p011, p111, p110, p010) # Top (+Y)
	_add_quad_direct(st, p001, p011, p010, p000) # Left (-X)
	_add_quad_direct(st, p100, p110, p111, p101) # Right (+X)

static func _build_ngon_frustum(st: SurfaceTool, y_bot: float, y_top: float, r_bot: float, r_top: float, angles: Array[float]) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_b0 := Vector3(cos(a0) * r_bot, y_bot, sin(a0) * r_bot)
		var p_b1 := Vector3(cos(a1) * r_bot, y_bot, sin(a1) * r_bot)
		var p_t1 := Vector3(cos(a1) * r_top, y_top, sin(a1) * r_top)
		var p_t0 := Vector3(cos(a0) * r_top, y_top, sin(a0) * r_top)

		_add_quad_direct(st, p_b0, p_b1, p_t1, p_t0)

static func _build_ngon_cap(st: SurfaceTool, y: float, r: float, angles: Array[float], is_top: bool) -> void:
	var n: int = angles.size()
	var center := Vector3(0.0, y, 0.0)
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r, y, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y, sin(a1) * r)
		if is_top:
			_add_triangle_direct(st, center, p0, p1)
		else:
			_add_triangle_direct(st, center, p1, p0)

static func _build_vertical_hex_ring(st: SurfaceTool, y_center: float, r_out: float, r_in: float, depth: float) -> void:
	var h_d: float = depth * 0.5
	var n: int = 6
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = float(i) * (TAU / 6.0)
		var a1: float = float(i_next) * (TAU / 6.0)

		var p_o0 := Vector3(cos(a0) * r_out, y_center + sin(a0) * r_out, h_d)
		var p_o1 := Vector3(cos(a1) * r_out, y_center + sin(a1) * r_out, h_d)
		var p_i1 := Vector3(cos(a1) * r_in, y_center + sin(a1) * r_in, h_d)
		var p_i0 := Vector3(cos(a0) * r_in, y_center + sin(a0) * r_in, h_d)

		var pb_o0 := Vector3(cos(a0) * r_out, y_center + sin(a0) * r_out, -h_d)
		var pb_o1 := Vector3(cos(a1) * r_out, y_center + sin(a1) * r_out, -h_d)
		var pb_i1 := Vector3(cos(a1) * r_in, y_center + sin(a1) * r_in, -h_d)
		var pb_i0 := Vector3(cos(a0) * r_in, y_center + sin(a0) * r_in, -h_d)

		_add_quad_direct(st, p_o0, p_o1, p_i1, p_i0)
		_add_quad_direct(st, pb_o1, pb_o0, pb_i0, pb_i1)
		_add_quad_direct(st, pb_o0, pb_o1, p_o1, p_o0)
		_add_quad_direct(st, p_i0, p_i1, pb_i1, pb_i0)

static func _build_corner_pillar(st: SurfaceTool, p_top: Vector3, p_bot: Vector3, width: float) -> void:
	var dir := (p_top - p_bot).normalized()
	var out_dir := Vector3(p_top.x, 0.0, p_top.z).normalized()
	var tangent := out_dir.cross(dir).normalized()
	var h_w: float = width * 0.5

	var p0 := p_bot - (tangent * h_w) + (out_dir * h_w)
	var p1 := p_bot + (tangent * h_w) + (out_dir * h_w)
	var p2 := p_top + (tangent * h_w) + (out_dir * h_w)
	var p3 := p_top - (tangent * h_w) + (out_dir * h_w)

	_add_quad_direct(st, p0, p1, p2, p3)

static func _add_quad_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle_direct(st, p0, p1, p2)
	_add_triangle_direct(st, p0, p2, p3)

static func _add_triangle_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
