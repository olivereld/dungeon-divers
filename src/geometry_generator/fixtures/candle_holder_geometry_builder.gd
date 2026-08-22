class_name CandleHolderGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de alta fidelidad y bajo poligonaje para el Candelabro Gótico (Candle Holder).
## Recrea con exactitud la topología de la referencia:
## 1. Peana circular escalonada con molduras biseladas ("HolderFrame").
## 2. 4 Puntales angulados de refuerzo en la base ("HolderFrame").
## 3. Fuste central cilíndrico con anillos y empuñadura decorativa ("HolderFrame").
## 4. Brazos simétricos curvados en arco hacia los lados ("HolderFrame").
## 5. 3 Cazoletas / platillos portavelas con reborde ("HolderFrame").
## 6. 3 Velas cilíndricas de cera con detalle de derretimiento ("CandlesWax").
## 7. 3 Llamas estilizadas en forma de gota con material emisivo ("CandleFlames").

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _CandleHolderGeometryConfigScript = preload("res://src/geometry_generator/config/candle_holder_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_candle_holder_fixture(config = null):
	if config == null:
		config = _CandleHolderGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"gothic_candle_holder"

	var s: float = config.scale_mult
	var num_sides: int = maxi(6, config.num_sides)
	var angles: Array[float] = []
	for i in range(num_sides):
		angles.append(float(i) * (TAU / float(num_sides)))

	# ==========================================================================
	# 1. ESTRUCTURA Y CUERPO METÁLICO/PÉTREO DEL CANDELABRO (HOLDER FRAME)
	# ==========================================================================
	var g_frame = _GeneratedMeshScript.new()
	g_frame.component_id = 0
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. PEANA CIRCULAR ESCALONADA (TIERED BASE) ---
	var y0: float = 0.0 * s
	var y1: float = 0.035 * s
	var y2: float = 0.065 * s
	var y3: float = 0.10 * s
	var y4: float = 0.16 * s

	var r_base0: float = config.base_radius * s
	var r_base1: float = (config.base_radius * 0.92) * s
	var r_base2: float = (config.base_radius * 0.78) * s
	var r_shaft: float = 0.042 * s

	# Fondo plano
	_build_ngon_cap(st_frame, y0, r_base0, angles, false)
	# Escalón inferior con bisel
	_build_ngon_frustum(st_frame, y0, y1, r_base0, r_base0, angles)
	_build_ngon_frustum(st_frame, y1, y2, r_base0, r_base1, angles)
	# Escalón superior con transición al cono
	_build_ngon_frustum(st_frame, y2, y3, r_base1, r_base2, angles)
	_build_ngon_frustum(st_frame, y3, y4, r_base2, r_shaft, angles)

	# --- B. 4 PUNTALES O PATAS ANGULADAS DE LA BASE (BUTTRESS STRUTS) ---
	var strut_count: int = 4
	var strut_r: float = 0.016 * s
	for i in range(strut_count):
		var a: float = float(i) * (TAU / 4.0) + (PI * 0.25)
		var p_top := Vector3(cos(a) * (r_shaft + 0.005 * s), y4 + 0.02 * s, sin(a) * (r_shaft + 0.005 * s))
		var p_bot := Vector3(cos(a) * (r_base2 * 0.85), y2, sin(a) * (r_base2 * 0.85))
		_build_cylinder_segment(st_frame, p_bot, p_top, strut_r, 6)

	# --- C. FUSTE CENTRAL CON ANILLOS Y EMPUÑADURA (CENTRAL STEM) ---
	var y_collar1_bot: float = 0.26 * s
	var y_collar1_top: float = 0.36 * s
	var y_branch_root: float = 0.46 * s
	var y_center_cup: float = 0.58 * s

	# Fuste inferior
	_build_ngon_frustum(st_frame, y4, y_collar1_bot, r_shaft, r_shaft, angles)
	# Anillo/Empuñadura central gruesa
	_build_ngon_frustum(st_frame, y_collar1_bot, y_collar1_top, r_shaft * 1.35, r_shaft * 1.35, angles)
	_build_ngon_frustum(st_frame, y_collar1_top, y_branch_root, r_shaft, r_shaft, angles)
	# Fuste superior central
	_build_ngon_frustum(st_frame, y_branch_root, y_center_cup, r_shaft, r_shaft * 1.1, angles)

	# --- D. BRAZOS LATERALES CURVADOS (CURVED BRANCH ARMS) ---
	var arm_span: float = config.arm_span * s
	var arm_r: float = 0.025 * s
	var y_side_cup: float = 0.52 * s

	# Brazo izquierdo (-X)
	var pts_left: Array[Vector3] = [
		Vector3(0.0, y_branch_root, 0.0),
		Vector3(-arm_span * 0.45, y_branch_root - 0.03 * s, 0.0),
		Vector3(-arm_span * 0.85, y_branch_root + 0.04 * s, 0.0),
		Vector3(-arm_span, y_side_cup, 0.0)
	]
	for i in range(pts_left.size() - 1):
		_build_cylinder_segment(st_frame, pts_left[i], pts_left[i + 1], arm_r, 6)

	# Brazo derecho (+X)
	var pts_right: Array[Vector3] = [
		Vector3(0.0, y_branch_root, 0.0),
		Vector3(arm_span * 0.45, y_branch_root - 0.03 * s, 0.0),
		Vector3(arm_span * 0.85, y_branch_root + 0.04 * s, 0.0),
		Vector3(arm_span, y_side_cup, 0.0)
	]
	for i in range(pts_right.size() - 1):
		_build_cylinder_segment(st_frame, pts_right[i], pts_right[i + 1], arm_r, 6)

	# --- E. 3 CAZOLETAS / PLATILLOS PORTAVELAS (DRIP CUPS) ---
	var r_cup_out: float = 0.065 * s
	var r_cup_in: float = 0.048 * s
	var cup_h: float = 0.035 * s

	# 1. Cazoleta central
	_build_drip_cup(st_frame, Vector3(0.0, y_center_cup, 0.0), r_cup_out, r_cup_in, cup_h, angles)
	# 2. Cazoleta izquierda
	_build_drip_cup(st_frame, Vector3(-arm_span, y_side_cup, 0.0), r_cup_out, r_cup_in, cup_h, angles)
	# 3. Cazoleta derecha
	_build_drip_cup(st_frame, Vector3(arm_span, y_side_cup, 0.0), r_cup_out, r_cup_in, cup_h, angles)

	st_frame.generate_tangents()
	var mesh_frame := ArrayMesh.new()
	mesh_frame = st_frame.commit(mesh_frame)
	mesh_frame.surface_set_name(0, "HolderFrame")
	g_frame.mesh = mesh_frame
	g_frame.material_slots[0] = _WallMaterialFactoryScript.create_trim_material()
	asset.add_mesh(&"holder_frame", g_frame)

	# ==========================================================================
	# 2. VELAS DE CERA ESCULPIDA (CANDLES WAX)
	# ==========================================================================
	var g_wax = _GeneratedMeshScript.new()
	g_wax.component_id = 1
	var st_wax := SurfaceTool.new()
	st_wax.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r_candle: float = 0.026 * s
	var h_candle_center: float = 0.16 * s
	var h_candle_side: float = 0.13 * s

	var y_wax_c := y_center_cup + cup_h
	var y_wax_l := y_side_cup + cup_h
	var y_wax_r := y_side_cup + cup_h

	# Vela central
	_build_candle_body(st_wax, Vector3(0.0, y_wax_c, 0.0), r_candle * 1.1, h_candle_center, angles)
	# Vela izquierda
	_build_candle_body(st_wax, Vector3(-arm_span, y_wax_l, 0.0), r_candle, h_candle_side, angles)
	# Vela derecha
	_build_candle_body(st_wax, Vector3(arm_span, y_wax_r, 0.0), r_candle, h_candle_side, angles)

	st_wax.generate_tangents()
	var mesh_wax := ArrayMesh.new()
	mesh_wax = st_wax.commit(mesh_wax)
	mesh_wax.surface_set_name(0, "CandlesWax")
	g_wax.mesh = mesh_wax

	# Material Cera Marfil Cálida
	var mat_wax := StandardMaterial3D.new()
	mat_wax.albedo_color = config.wax_color
	mat_wax.roughness = 0.65
	mat_wax.metallic = 0.0
	g_wax.material_slots[0] = mat_wax
	asset.add_mesh(&"candles_wax", g_wax)

	# ==========================================================================
	# 3. LLAMAS EMISIVAS EN GOTA (CANDLE FLAMES)
	# ==========================================================================
	var g_flames = _GeneratedMeshScript.new()
	g_flames.component_id = 2
	var st_flames := SurfaceTool.new()
	st_flames.begin(Mesh.PRIMITIVE_TRIANGLES)

	var flame_sz: float = 0.038 * s

	# Llama central
	_build_teardrop_flame(st_flames, Vector3(0.0, y_wax_c + h_candle_center + 0.01 * s, 0.0), flame_sz * 1.1)
	# Llama izquierda
	_build_teardrop_flame(st_flames, Vector3(-arm_span, y_wax_l + h_candle_side + 0.01 * s, 0.0), flame_sz)
	# Llama derecha
	_build_teardrop_flame(st_flames, Vector3(arm_span, y_wax_r + h_candle_side + 0.01 * s, 0.0), flame_sz)

	st_flames.generate_tangents()
	var mesh_flames := ArrayMesh.new()
	mesh_flames = st_flames.commit(mesh_flames)
	mesh_flames.surface_set_name(0, "CandleFlames")
	g_flames.mesh = mesh_flames

	# Material Llama Emisiva
	var mat_flame := StandardMaterial3D.new()
	var flame_col: Color = config.flame_color if config != null and "flame_color" in config else Color(1.0, 0.70, 0.20, 1.0)
	mat_flame.albedo_color = flame_col
	mat_flame.roughness = 0.1
	mat_flame.emission_enabled = true
	mat_flame.emission = flame_col
	mat_flame.emission_energy_multiplier = 3.6
	g_flames.material_slots[0] = mat_flame
	asset.add_mesh(&"candle_flames", g_flames)

	# ==========================================================================
	# 4. COLISIÓN FÍSICA
	# ==========================================================================
	var col_shape := CylinderShape3D.new()
	col_shape.radius = config.base_radius * 0.95 * s
	col_shape.height = (y_center_cup + h_candle_center + flame_sz)
	g_frame.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, col_shape.height * 0.5, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS AUXILIARES
# ==============================================================================

static func _build_drip_cup(st: SurfaceTool, pos: Vector3, r_out: float, r_in: float, height: float, angles: Array[float]) -> void:
	var y_bot: float = pos.y
	var y_top: float = pos.y + height
	var n: int = angles.size()

	# Copa exterior
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_b0 := pos + Vector3(cos(a0) * (r_out * 0.6), 0.0, sin(a0) * (r_out * 0.6))
		var p_b1 := pos + Vector3(cos(a1) * (r_out * 0.6), 0.0, sin(a1) * (r_out * 0.6))
		var p_t1 := pos + Vector3(cos(a1) * r_out, height, sin(a1) * r_out)
		var p_t0 := pos + Vector3(cos(a0) * r_out, height, sin(a0) * r_out)

		_add_quad_direct(st, p_b0, p_b1, p_t1, p_t0)

		# Reborde superior hacia el interior
		var p_in1 := pos + Vector3(cos(a1) * r_in, height, sin(a1) * r_in)
		var p_in0 := pos + Vector3(cos(a0) * r_in, height, sin(a0) * r_in)
		_add_quad_direct(st, p_t0, p_t1, p_in1, p_in0)

static func _build_candle_body(st: SurfaceTool, pos: Vector3, radius: float, height: float, angles: Array[float]) -> void:
	var y_bot: float = pos.y
	var y_top: float = pos.y + height
	var n: int = angles.size()

	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_b0 := pos + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p_b1 := pos + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var p_t1 := pos + Vector3(cos(a1) * radius, height, sin(a1) * radius)
		var p_t0 := pos + Vector3(cos(a0) * radius, height, sin(a0) * radius)

		_add_quad_direct(st, p_b0, p_b1, p_t1, p_t0)

	# Tapa superior cóncava de la vela
	var center_top := pos + Vector3(0.0, height - (radius * 0.3), 0.0)
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := pos + Vector3(cos(a0) * radius, height, sin(a0) * radius)
		var p1 := pos + Vector3(cos(a1) * radius, height, sin(a1) * radius)
		_add_triangle_direct(st, center_top, p0, p1)

static func _build_teardrop_flame(st: SurfaceTool, pos: Vector3, size: float) -> void:
	var hx: float = size * 0.45
	var hy: float = size
	var hz: float = size * 0.45

	var peak := pos + Vector3(0.0, hy, 0.0)
	var bot := pos
	var mid_y := pos.y + hy * 0.35

	var v0 := Vector3(pos.x + hx, mid_y, pos.z)
	var v1 := Vector3(pos.x, mid_y, pos.z + hz)
	var v2 := Vector3(pos.x - hx, mid_y, pos.z)
	var v3 := Vector3(pos.x, mid_y, pos.z - hz)

	# Cono superior hacia la punta
	_add_triangle_direct(st, peak, v0, v1)
	_add_triangle_direct(st, peak, v1, v2)
	_add_triangle_direct(st, peak, v2, v3)
	_add_triangle_direct(st, peak, v3, v0)

	# Cono inferior redondeado hacia la mecha
	_add_triangle_direct(st, bot, v1, v0)
	_add_triangle_direct(st, bot, v2, v1)
	_add_triangle_direct(st, bot, v3, v2)
	_add_triangle_direct(st, bot, v0, v3)

static func _build_cylinder_segment(st: SurfaceTool, p_start: Vector3, p_end: Vector3, radius: float, sides: int = 6) -> void:
	var forward: Vector3 = (p_end - p_start).normalized()
	if forward.length_squared() < 0.0001:
		return

	var right := Vector3(1.0, 0.0, 0.0)
	var up := forward.cross(right).normalized()
	if up.length_squared() < 0.0001:
		up = Vector3(0.0, 1.0, 0.0)
		right = up.cross(forward).normalized()
	else:
		right = forward.cross(up).normalized()

	for i in range(sides):
		var i_next: int = (i + 1) % sides
		var a0: float = float(i) * (TAU / float(sides))
		var a1: float = float(i_next) * (TAU / float(sides))

		var off0 := (right * cos(a0) + up * sin(a0)) * radius
		var off1 := (right * cos(a1) + up * sin(a1)) * radius

		var a_bot := p_start + off0
		var b_bot := p_start + off1
		var b_top := p_end + off1
		var a_top := p_end + off0

		_add_quad_direct(st, a_bot, b_bot, b_top, a_top)

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
