class_name ChairGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Sillas y Taburetes (Chair).
## Geometría estilizada sólida y estanca con normales y devanado CCW garantizados:
## 1. `chair_wood`: Madera principal uniforme de roble.
## 2. `chair_trim`: Herrajes, pernos y tallas ornamentales.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _ChairGeometryConfigScript = preload("res://src/geometry_generator/config/chair_geometry_config.gd")

func build_chair_fixture(config = null):
	if config == null:
		config = _ChairGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_tavern_chair"

	var s: float = config.scale_mult
	var seat_h: float = config.seat_height * s
	var s_thick: float = config.seat_thickness * s

	var g_wood = _GeneratedMeshScript.new()
	g_wood.component_id = 0
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	match config.style:
		_ChairGeometryConfigScript.ChairStyle.TAVERN_STOOL:
			_build_tavern_stool(st_wood, st_trim, s, seat_h, s_thick)
		_ChairGeometryConfigScript.ChairStyle.GOTHIC_HIGHBACK:
			_build_gothic_highback(st_wood, st_trim, s, seat_h, s_thick)
		_ChairGeometryConfigScript.ChairStyle.TAVERN_ARMCHAIR:
			_build_tavern_armchair(st_wood, st_trim, s, seat_h, s_thick)

	# Commit madera
	var mesh_wood := ArrayMesh.new()
	mesh_wood = st_wood.commit(mesh_wood)
	mesh_wood.surface_set_name(0, "ChairWood")
	g_wood.mesh = mesh_wood

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = config.wood_color
	mat_wood.roughness = 0.70
	mat_wood.metallic = 0.0
	mat_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood.material_slots[0] = mat_wood
	asset.add_mesh(&"chair_wood", g_wood)

	# Commit trim
	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	if mesh_trim.get_surface_count() > 0:
		mesh_trim.surface_set_name(0, "ChairTrim")
		g_trim.mesh = mesh_trim

		var mat_trim := StandardMaterial3D.new()
		mat_trim.albedo_color = config.wood_trim_color
		mat_trim.roughness = 0.55
		mat_trim.metallic = 0.0
		mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_trim.material_slots[0] = mat_trim
		asset.add_mesh(&"chair_trim", g_trim)

	# Colisión física
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(0.60 * s, 1.15 * s, 0.60 * s)
	g_wood.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, 0.55 * s, 0.0)))

	return asset

# ==============================================================================
# 1. TABURETE REDONDO DE TABERNA
# ==============================================================================

static func _build_tavern_stool(
	st_w: SurfaceTool, _st_t: SurfaceTool,
	s: float, seat_h: float, s_thick: float
) -> void:
	var r: float = 0.22 * s
	var segs: int = 16
	var top_y := seat_h
	var bot_y := seat_h - s_thick

	# 1. Asiento circular de madera
	for i in range(segs):
		var a0: float = float(i) * (TAU / float(segs))
		var a1: float = float(i + 1) * (TAU / float(segs))

		var p_top_c := Vector3(0.0, top_y, 0.0)
		var p_top0 := Vector3(cos(a0) * r, top_y, sin(a0) * r)
		var p_top1 := Vector3(cos(a1) * r, top_y, sin(a1) * r)

		var p_bot_c := Vector3(0.0, bot_y, 0.0)
		var p_bot0 := Vector3(cos(a0) * r, bot_y, sin(a0) * r)
		var p_bot1 := Vector3(cos(a1) * r, bot_y, sin(a1) * r)

		# Tapa superior
		_add_tri_facing(st_w, p_top_c, p_top0, p_top1, Vector3(0, 1, 0))
		# Tapa inferior
		_add_tri_facing(st_w, p_bot_c, p_bot1, p_bot0, Vector3(0, -1, 0))
		# Borde lateral
		var n_side := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5)).normalized()
		_add_quad_facing(st_w, p_bot0, p_bot1, p_top1, p_top0, n_side)

	# Ranuras de corte de tablones en el asiento
	_build_solid_box(st_w, Vector3(0.0, top_y + 0.002 * s, 0.07 * s), Vector3(r * 1.84, 0.004 * s, 0.012 * s))
	_build_solid_box(st_w, Vector3(0.0, top_y + 0.002 * s, -0.07 * s), Vector3(r * 1.84, 0.004 * s, 0.012 * s))

	# 2. 4 Patas abiertas simétricamente de adentro hacia afuera
	var top_r: float = 0.09 * s
	var bot_r: float = 0.16 * s
	var leg_w: float = 0.052 * s

	var leg_top_pts = [
		Vector3(-top_r, bot_y, -top_r),
		Vector3(top_r, bot_y, -top_r),
		Vector3(top_r, bot_y, top_r),
		Vector3(-top_r, bot_y, top_r)
	]

	var leg_bot_pts = [
		Vector3(-bot_r, 0.0, -bot_r),
		Vector3(bot_r, 0.0, -bot_r),
		Vector3(bot_r, 0.0, bot_r),
		Vector3(-bot_r, 0.0, bot_r)
	]

	for i in range(4):
		_build_tapered_leg(st_w, leg_top_pts[i], leg_bot_pts[i], leg_w, leg_w)

	# 3. 4 Travesaños de reposapiés a media altura conectando las 4 patas
	var bar_y: float = 0.16 * s
	var t_factor: float = bar_y / bot_y
	var mid_pts: Array[Vector3] = []
	for i in range(4):
		mid_pts.append(leg_bot_pts[i].lerp(leg_top_pts[i], t_factor))

	var bar_thick: float = 0.034 * s

	# Travesaño Trasero (0 a 1: Z negativo)
	var len_x: float = abs(mid_pts[1].x - mid_pts[0].x)
	_build_solid_box(st_w, Vector3(0.0, bar_y, mid_pts[0].z), Vector3(len_x, bar_thick, bar_thick))
	# Travesaño Frontal (3 a 2: Z positivo)
	_build_solid_box(st_w, Vector3(0.0, bar_y, mid_pts[2].z), Vector3(len_x, bar_thick, bar_thick))
	# Travesaño Izquierdo (0 a 3: X negativo)
	var len_z: float = abs(mid_pts[3].z - mid_pts[0].z)
	_build_solid_box(st_w, Vector3(mid_pts[0].x, bar_y, 0.0), Vector3(bar_thick, bar_thick, len_z))
	# Travesaño Derecho (1 a 2: X positivo)
	_build_solid_box(st_w, Vector3(mid_pts[1].x, bar_y, 0.0), Vector3(bar_thick, bar_thick, len_z))

# ==============================================================================
# 2. SILLA GÓTICA DE RESPALDO ALTO
# ==============================================================================

static func _build_gothic_highback(
	st_w: SurfaceTool, st_t: SurfaceTool,
	s: float, seat_h: float, s_thick: float
) -> void:
	var sw: float = 0.46 * s
	var sd: float = 0.46 * s
	var top_y := seat_h
	var bot_y := seat_h - s_thick

	# 1. Asiento cuadrado biselado
	_build_solid_box(st_w, Vector3(0.0, top_y - s_thick * 0.5, 0.0), Vector3(sw, s_thick, sd))

	# 2. Faldón bajo el asiento
	var apron_h: float = 0.05 * s
	var apron_y: float = bot_y - apron_h * 0.5
	_build_solid_box(st_w, Vector3(0.0, apron_y, -sd * 0.42), Vector3(sw * 0.88, apron_h, 0.03 * s))
	_build_solid_box(st_w, Vector3(0.0, apron_y, sd * 0.42), Vector3(sw * 0.88, apron_h, 0.03 * s))
	_build_solid_box(st_w, Vector3(-sw * 0.42, apron_y, 0.0), Vector3(0.03 * s, apron_h, sd * 0.88))
	_build_solid_box(st_w, Vector3(sw * 0.42, apron_y, 0.0), Vector3(0.03 * s, apron_h, sd * 0.88))

	# 3. 4 Patas con molduras cuadradas
	var leg_w: float = 0.055 * s
	var leg_h: float = bot_y
	var leg_hx: float = sw * 0.40
	var leg_hz: float = sd * 0.40

	var leg_pos = [
		Vector3(-leg_hx, leg_h * 0.5, -leg_hz),
		Vector3(leg_hx, leg_h * 0.5, -leg_hz),
		Vector3(-leg_hx, leg_h * 0.5, leg_hz),
		Vector3(leg_hx, leg_h * 0.5, leg_hz)
	]

	for p in leg_pos:
		_build_solid_box(st_w, p, Vector3(leg_w, leg_h, leg_w))
		# Base de pata
		_build_solid_box(st_t, Vector3(p.x, 0.02 * s, p.z), Vector3(leg_w + 0.015 * s, 0.04 * s, leg_w + 0.015 * s))

	# Travesaños inferiores
	var t_bar_y: float = 0.12 * s
	_build_solid_box(st_w, Vector3(0.0, t_bar_y, -leg_hz), Vector3(sw * 0.80, 0.03 * s, 0.03 * s))
	_build_solid_box(st_w, Vector3(0.0, t_bar_y, leg_hz), Vector3(sw * 0.80, 0.03 * s, 0.03 * s))
	_build_solid_box(st_w, Vector3(0.0, t_bar_y, 0.0), Vector3(0.03 * s, 0.03 * s, sd * 0.80))

	# 4. Respaldo Alto Gótico
	var back_h: float = 0.70 * s
	var back_top_y: float = top_y + back_h
	var post_w: float = 0.048 * s
	var back_z: float = -leg_hz

	# Postes laterales continuos del respaldo
	var post_cy: float = top_y + back_h * 0.5
	_build_solid_box(st_w, Vector3(-leg_hx, post_cy, back_z), Vector3(post_w, back_h, post_w))
	_build_solid_box(st_w, Vector3(leg_hx, post_cy, back_z), Vector3(post_w, back_h, post_w))

	# Travesaño inferior del respaldo (anclaje de los barrotes)
	var rail_bot_y: float = top_y + 0.07 * s
	var rail_h: float = 0.045 * s
	_build_solid_box(st_w, Vector3(0.0, rail_bot_y, back_z), Vector3(sw * 0.88, rail_h, 0.04 * s))

	# 2 soportes verticales inferiores que unen el travesaño inferior con el asiento
	_build_solid_box(st_w, Vector3(-sw * 0.28, top_y + 0.025 * s, back_z), Vector3(0.04 * s, 0.05 * s, 0.035 * s))
	_build_solid_box(st_w, Vector3(sw * 0.28, top_y + 0.025 * s, back_z), Vector3(0.04 * s, 0.05 * s, 0.035 * s))

	# Travesaño superior del marco del respaldo
	var rail_top_y: float = back_top_y - 0.025 * s
	_build_solid_box(st_w, Vector3(0.0, rail_top_y, back_z), Vector3(sw * 0.88, 0.05 * s, 0.04 * s))

	# Arco ojival superior / Copete conopial gótico
	var crest_cy: float = back_top_y + 0.08 * s
	_build_solid_box(st_w, Vector3(0.0, crest_cy, back_z), Vector3(sw * 0.88, 0.12 * s, 0.04 * s))
	_build_solid_box(st_t, Vector3(0.0, back_top_y + 0.16 * s, back_z), Vector3(0.12 * s, 0.08 * s, 0.045 * s))

	# Barrotillos verticales perfectamente anclados entre el travesaño inferior y superior
	var slat_count: int = 5
	var slat_w: float = 0.026 * s
	var slat_bottom_y: float = rail_bot_y + rail_h * 0.5
	var slat_top_y: float = rail_top_y - 0.025 * s
	var slat_h: float = slat_top_y - slat_bottom_y
	var slat_cy: float = slat_bottom_y + slat_h * 0.5

	for i in range(slat_count):
		var fx: float = (float(i) / float(slat_count - 1) - 0.5) * (sw * 0.62)
		_build_solid_box(st_w, Vector3(fx, slat_cy, back_z), Vector3(slat_w, slat_h, 0.028 * s))

# ==============================================================================
# 3. SILLÓN DE TABERNA CON REPOSABRAZOS
# ==============================================================================

static func _build_tavern_armchair(
	st_w: SurfaceTool, st_t: SurfaceTool,
	s: float, seat_h: float, s_thick: float
) -> void:
	var sw: float = 0.54 * s
	var sd: float = 0.52 * s
	var top_y := seat_h
	var bot_y := seat_h - s_thick

	# 1. Asiento de 3 tablones gruesos
	var plank_w: float = (sd - 0.02 * s) / 3.0
	for i in range(3):
		var pz: float = (float(i) - 1.0) * (plank_w + 0.008 * s)
		_build_solid_box(st_w, Vector3(0.0, top_y - s_thick * 0.5, pz), Vector3(sw, s_thick, plank_w))

	# 2. 4 Postes / Patas principales
	var leg_w: float = 0.062 * s
	var leg_hx: float = sw * 0.44
	var leg_hz: float = sd * 0.42

	# Patas delanteras (suben hasta el reposabrazos: Y = 0.65m)
	var front_top_y: float = 0.66 * s
	_build_solid_box(st_w, Vector3(-leg_hx, front_top_y * 0.5, leg_hz), Vector3(leg_w, front_top_y, leg_w))
	_build_solid_box(st_w, Vector3(leg_hx, front_top_y * 0.5, leg_hz), Vector3(leg_w, front_top_y, leg_w))

	# Patas traseras (suben continuas hasta el respaldo: Y = 1.05m)
	var back_top_y: float = 1.06 * s
	_build_solid_box(st_w, Vector3(-leg_hx, back_top_y * 0.5, -leg_hz), Vector3(leg_w, back_top_y, leg_w))
	_build_solid_box(st_w, Vector3(leg_hx, back_top_y * 0.5, -leg_hz), Vector3(leg_w, back_top_y, leg_w))

	# Remates de los postes traseros
	_build_solid_box(st_t, Vector3(-leg_hx, back_top_y + 0.02 * s, -leg_hz), Vector3(leg_w * 1.15, 0.04 * s, leg_w * 1.15))
	_build_solid_box(st_t, Vector3(leg_hx, back_top_y + 0.02 * s, -leg_hz), Vector3(leg_w * 1.15, 0.04 * s, leg_w * 1.15))

	# 3. 2 Reposabrazos curvados
	var arm_len: float = sd * 0.90
	var arm_y: float = 0.65 * s
	var arm_w: float = 0.065 * s
	var arm_h: float = 0.045 * s

	# Brazo izquierdo
	_build_solid_box(st_w, Vector3(-leg_hx, arm_y, 0.0), Vector3(arm_w, arm_h, arm_len))
	_build_solid_box(st_t, Vector3(-leg_hx, arm_y + 0.015 * s, leg_hz + 0.02 * s), Vector3(arm_w * 1.2, 0.06 * s, 0.07 * s))

	# Brazo derecho
	_build_solid_box(st_w, Vector3(leg_hx, arm_y, 0.0), Vector3(arm_w, arm_h, arm_len))
	_build_solid_box(st_t, Vector3(leg_hx, arm_y + 0.015 * s, leg_hz + 0.02 * s), Vector3(arm_w * 1.2, 0.06 * s, 0.07 * s))

	# 4. Respaldo de 3 tablones verticales gruesos
	var back_plank_w: float = 0.10 * s
	var back_plank_h: float = back_top_y - top_y - 0.08 * s
	var back_plank_cy: float = top_y + back_plank_h * 0.5 + 0.04 * s

	for i in range(3):
		var bx: float = (float(i) - 1.0) * (back_plank_w + 0.02 * s)
		_build_solid_box(st_w, Vector3(bx, back_plank_cy, -leg_hz), Vector3(back_plank_w, back_plank_h, 0.035 * s))

	# Travesaño superior del respaldo
	_build_solid_box(st_w, Vector3(0.0, back_top_y - 0.04 * s, -leg_hz), Vector3(sw * 0.88, 0.07 * s, 0.045 * s))
	# Medallón central
	_build_solid_box(st_t, Vector3(0.0, back_top_y - 0.04 * s, -leg_hz + 0.02 * s), Vector3(0.08 * s, 0.08 * s, 0.018 * s))

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS CON NORMALES DIRIGIDAS
# ==============================================================================

static func _build_solid_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var x0 := center.x - hx; var x1 := center.x + hx
	var y0 := center.y - hy; var y1 := center.y + hy
	var z0 := center.z - hz; var z1 := center.z + hz

	# 1. Frontal (+Z) -> Normal (0, 0, 1)
	_add_quad_facing(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(0, 0, 1))
	# 2. Trasera (-Z) -> Normal (0, 0, -1)
	_add_quad_facing(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(0, 0, -1))
	# 3. Derecha (+X) -> Normal (1, 0, 0)
	_add_quad_facing(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(1, 0, 0))
	# 4. Izquierda (-X) -> Normal (-1, 0, 0)
	_add_quad_facing(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(-1, 0, 0))
	# 5. Superior (+Y) -> Normal (0, 1, 0)
	_add_quad_facing(st, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(0, 1, 0))
	# 6. Inferior (-Y) -> Normal (0, -1, 0)
	_add_quad_facing(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(0, -1, 0))

static func _build_tapered_leg(
	st: SurfaceTool,
	p_top: Vector3,
	p_bot: Vector3,
	w_top: float,
	w_bot: float
) -> void:
	var hwt := w_top * 0.5
	var hwb := w_bot * 0.5

	# 4 vértices superiores en p_top
	var v_tl_top := p_top + Vector3(-hwt, 0.0, -hwt)
	var v_tr_top := p_top + Vector3(hwt, 0.0, -hwt)
	var v_br_top := p_top + Vector3(hwt, 0.0, hwt)
	var v_bl_top := p_top + Vector3(-hwt, 0.0, hwt)

	# 4 vértices inferiores en p_bot
	var v_tl_bot := p_bot + Vector3(-hwb, 0.0, -hwb)
	var v_tr_bot := p_bot + Vector3(hwb, 0.0, -hwb)
	var v_br_bot := p_bot + Vector3(hwb, 0.0, hwb)
	var v_bl_bot := p_bot + Vector3(-hwb, 0.0, hwb)

	# 1. Cara frontal (+Z)
	_add_quad_facing(st, v_bl_bot, v_br_bot, v_br_top, v_bl_top, Vector3(0, 0, 1))
	# 2. Cara trasera (-Z)
	_add_quad_facing(st, v_tr_bot, v_tl_bot, v_tl_top, v_tr_top, Vector3(0, 0, -1))
	# 3. Cara derecha (+X)
	_add_quad_facing(st, v_br_bot, v_tr_bot, v_tr_top, v_br_top, Vector3(1, 0, 0))
	# 4. Cara izquierda (-X)
	_add_quad_facing(st, v_tl_bot, v_bl_bot, v_bl_top, v_tl_top, Vector3(-1, 0, 0))
	# 5. Cara superior (+Y)
	_add_quad_facing(st, v_tl_top, v_tr_top, v_br_top, v_bl_top, Vector3(0, 1, 0))
	# 6. Cara inferior (-Y)
	_add_quad_facing(st, v_tl_bot, v_bl_bot, v_br_bot, v_tr_bot, Vector3(0, -1, 0))

static func _build_oriented_solid_box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v_bl_f := xform * Vector3(-hx, -hy, hz)
	var v_br_f := xform * Vector3(hx, -hy, hz)
	var v_tr_f := xform * Vector3(hx, hy, hz)
	var v_tl_f := xform * Vector3(-hx, hy, hz)

	var v_bl_b := xform * Vector3(-hx, -hy, -hz)
	var v_br_b := xform * Vector3(hx, -hy, -hz)
	var v_tr_b := xform * Vector3(hx, hy, -hz)
	var v_tl_b := xform * Vector3(-hx, hy, -hz)

	var n_front := xform.basis.z.normalized()
	var n_back := -xform.basis.z.normalized()
	var n_right := xform.basis.x.normalized()
	var n_left := -xform.basis.x.normalized()
	var n_top := xform.basis.y.normalized()
	var n_bot := -xform.basis.y.normalized()

	_add_quad_facing(st, v_bl_f, v_br_f, v_tr_f, v_tl_f, n_front)
	_add_quad_facing(st, v_br_b, v_bl_b, v_tl_b, v_tr_b, n_back)
	_add_quad_facing(st, v_br_f, v_br_b, v_tr_b, v_tr_f, n_right)
	_add_quad_facing(st, v_bl_b, v_bl_f, v_tl_f, v_tl_b, n_left)
	_add_quad_facing(st, v_tl_f, v_tr_f, v_tr_b, v_tl_b, n_top)
	_add_quad_facing(st, v_bl_b, v_br_b, v_br_f, v_bl_f, n_bot)

static func _add_quad_facing(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, expected_normal: Vector3) -> void:
	var n: Vector3 = (p1 - p0).cross(p2 - p0)
	if n.dot(expected_normal) >= 0.0:
		_add_tri_facing(st, p0, p1, p2, expected_normal)
		_add_tri_facing(st, p0, p2, p3, expected_normal)
	else:
		_add_tri_facing(st, p0, p3, p2, expected_normal)
		_add_tri_facing(st, p0, p2, p1, expected_normal)

static func _add_tri_facing(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
