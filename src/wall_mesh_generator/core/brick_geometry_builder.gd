class_name BrickGeometryBuilder
extends RefCounted

## Generador procedural de geometría para paredes, esquinas y arcos estilizados (estilo Zelda / KayKit).
## Geometría 100% monolítica, continua y estanca (watertight) con normales y devanado CCW correctos.

# ==============================================================================
# 1. ARCOS DE PUERTA / PORTALES ESTILIZADOS (ARCH PROCEDURAL GEOMETRY)
# ==============================================================================

## Añade la cornisa superior del arco con bloques modulares y ranuras en V.
static func append_arch_top_cornice(
	st: SurfaceTool,
	total_width: float,
	total_height: float,
	slope_height: float,
	wall_thickness: float,
	trim_overhang: float,
	transform: Transform3D,
	notch_width: float = 0.065,
	notch_depth: float = 0.040
) -> void:
	var pillar_w: float = 0.46
	var center_w: float = total_width - (pillar_w * 2.0)
	var half_w: float = total_width * 0.5

	# 1. Bloque Cornisa Izquierda
	var t_left := transform * Transform3D(Basis(), Vector3(-half_w + (pillar_w * 0.5), 0.0, 0.0))
	append_top_cornice(st, pillar_w - (notch_width * 0.5), total_height, slope_height, wall_thickness, trim_overhang, t_left)

	# 2. Bloque Cornisa Central
	var t_mid := transform * Transform3D(Basis(), Vector3(0.0, 0.0, 0.0))
	append_top_cornice(st, center_w - notch_width, total_height, slope_height, wall_thickness, trim_overhang, t_mid)

	# 3. Bloque Cornisa Derecha
	var t_right := transform * Transform3D(Basis(), Vector3(half_w - (pillar_w * 0.5), 0.0, 0.0))
	append_top_cornice(st, pillar_w - (notch_width * 0.5), total_height, slope_height, wall_thickness, trim_overhang, t_right)

## Añade las bases inferiores (zócalos) de los pilares del arco con bisel a 45°.
static func append_arch_bottom_base(
	st: SurfaceTool,
	total_width: float,
	total_height: float,
	slope_height: float,
	wall_thickness: float,
	trim_overhang: float,
	opening_width: float,
	transform: Transform3D
) -> void:
	var pillar_w: float = (total_width - opening_width) * 0.5
	var half_w: float = total_width * 0.5
	var half_pillar: float = pillar_w * 0.5

	# Pilar Izquierdo
	var t_left := transform * Transform3D(Basis(), Vector3(-half_w + half_pillar, 0.0, 0.0))
	append_bottom_base(st, pillar_w, total_height, slope_height, wall_thickness, trim_overhang, t_left)

	# Pilar Derecho
	var t_right := transform * Transform3D(Basis(), Vector3(half_w - half_pillar, 0.0, 0.0))
	append_bottom_base(st, pillar_w, total_height, slope_height, wall_thickness, trim_overhang, t_right)

## Añade el panel de pared del arco como una SUPERFICIE MONOLÍTICA CONTINUA (Cero cortes ni costuras).
static func append_arch_wall_panel(
	st: SurfaceTool,
	total_width: float,
	panel_height: float,
	wall_thickness: float,
	opening_width: float,
	opening_height: float,
	inner_bevel: float,
	transform: Transform3D,
	bevel: float = 0.012
) -> void:
	var half_w: float = total_width * 0.5
	var half_open_w: float = opening_width * 0.5
	var half_t: float = wall_thickness * 0.5

	var radius: float = half_open_w
	var spring_y: float = clampf(opening_height - radius, 0.2, panel_height - radius - 0.05)
	var arch_top_y: float = spring_y + radius

	var num_segs: int = 16
	var curve_pts: Array[Vector2] = [] # (x, y) de la curva semicircular de izquierda a derecha

	for s in range(num_segs + 1):
		var angle: float = PI - (float(s) / float(num_segs) * PI) # de PI a 0
		var cx: float = cos(angle) * radius
		var cy: float = spring_y + (sin(angle) * radius)
		curve_pts.append(Vector2(cx, cy))

	# --------------------------------------------------------------------------
	# 1. CARA FRONTAL MONOLÍTICA (+Z) (Sin divisiones ni costuras internas)
	# --------------------------------------------------------------------------
	# 1.1 Columna Izquierda Frontal
	_add_quad_direct(st, transform,
		Vector3(-half_w, 0.0, half_t),
		Vector3(-half_open_w, 0.0, half_t),
		Vector3(-half_open_w, spring_y, half_t),
		Vector3(-half_w, spring_y, half_t)
	)
	_add_quad_direct(st, transform,
		Vector3(-half_w, spring_y, half_t),
		Vector3(-half_open_w, spring_y, half_t),
		Vector3(-half_open_w, panel_height, half_t),
		Vector3(-half_w, panel_height, half_t)
	)

	# 1.2 Columna Derecha Frontal
	_add_quad_direct(st, transform,
		Vector3(half_open_w, 0.0, half_t),
		Vector3(half_w, 0.0, half_t),
		Vector3(half_w, spring_y, half_t),
		Vector3(half_open_w, spring_y, half_t)
	)
	_add_quad_direct(st, transform,
		Vector3(half_open_w, spring_y, half_t),
		Vector3(half_w, spring_y, half_t),
		Vector3(half_w, panel_height, half_t),
		Vector3(half_open_w, panel_height, half_t)
	)

	# 1.3 Dintel Frontal sobre la Bóveda del Arco (Conecta la curva directamente al borde superior)
	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]

		var top_x0: float = p0.x
		var top_x1: float = p1.x

		_add_quad_direct(st, transform,
			Vector3(p0.x, p0.y, half_t),
			Vector3(p1.x, p1.y, half_t),
			Vector3(top_x1, panel_height, half_t),
			Vector3(top_x0, panel_height, half_t)
		)

	# --------------------------------------------------------------------------
	# 2. CARA TRASERA MONOLÍTICA (-Z)
	# --------------------------------------------------------------------------
	# 2.1 Columna Izquierda Trasera
	_add_quad_direct(st, transform,
		Vector3(-half_open_w, 0.0, -half_t),
		Vector3(-half_w, 0.0, -half_t),
		Vector3(-half_w, spring_y, -half_t),
		Vector3(-half_open_w, spring_y, -half_t)
	)
	_add_quad_direct(st, transform,
		Vector3(-half_open_w, spring_y, -half_t),
		Vector3(-half_w, spring_y, -half_t),
		Vector3(-half_w, panel_height, -half_t),
		Vector3(-half_open_w, panel_height, -half_t)
	)

	# 2.2 Columna Derecha Trasera
	_add_quad_direct(st, transform,
		Vector3(half_w, 0.0, -half_t),
		Vector3(half_open_w, 0.0, -half_t),
		Vector3(half_open_w, spring_y, -half_t),
		Vector3(half_w, spring_y, -half_t)
	)
	_add_quad_direct(st, transform,
		Vector3(half_w, spring_y, -half_t),
		Vector3(half_open_w, spring_y, -half_t),
		Vector3(half_open_w, panel_height, -half_t),
		Vector3(half_w, panel_height, -half_t)
	)

	# 2.3 Dintel Trasero sobre la Bóveda
	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]

		var top_x0: float = p0.x
		var top_x1: float = p1.x

		_add_quad_direct(st, transform,
			Vector3(p1.x, p1.y, -half_t),
			Vector3(p0.x, p0.y, -half_t),
			Vector3(top_x0, panel_height, -half_t),
			Vector3(top_x1, panel_height, -half_t)
		)

	# --------------------------------------------------------------------------
	# 3. INTRADÓS DEL ARCO (Cara interior del túnel / bóveda y jambas)
	# --------------------------------------------------------------------------
	# 3.1 Bóveda semicircular
	for s in range(num_segs):
		var p0: Vector2 = curve_pts[s]
		var p1: Vector2 = curve_pts[s + 1]

		_add_quad_direct(st, transform,
			Vector3(p0.x, p0.y, half_t),
			Vector3(p0.x, p0.y, -half_t),
			Vector3(p1.x, p1.y, -half_t),
			Vector3(p1.x, p1.y, half_t)
		)

	# 3.2 Jamba Vertical Izquierda (Interior)
	_add_quad_direct(st, transform,
		Vector3(-half_open_w, 0.0, half_t),
		Vector3(-half_open_w, 0.0, -half_t),
		Vector3(-half_open_w, spring_y, -half_t),
		Vector3(-half_open_w, spring_y, half_t)
	)

	# 3.3 Jamba Vertical Derecha (Interior)
	_add_quad_direct(st, transform,
		Vector3(half_open_w, 0.0, -half_t),
		Vector3(half_open_w, 0.0, half_t),
		Vector3(half_open_w, spring_y, half_t),
		Vector3(half_open_w, spring_y, -half_t)
	)

	# --------------------------------------------------------------------------
	# 4. CARAS EXTERIORES (Izquierda, Derecha, Superior e Inferior)
	# --------------------------------------------------------------------------
	# Cara Exterior Izquierda (-X)
	_add_quad_direct(st, transform,
		Vector3(-half_w, 0.0, -half_t),
		Vector3(-half_w, 0.0, half_t),
		Vector3(-half_w, panel_height, half_t),
		Vector3(-half_w, panel_height, -half_t)
	)

	# Cara Exterior Derecha (+X)
	_add_quad_direct(st, transform,
		Vector3(half_w, 0.0, half_t),
		Vector3(half_w, 0.0, -half_t),
		Vector3(half_w, panel_height, -half_t),
		Vector3(half_w, panel_height, half_t)
	)

	# Cara Superior (+Y)
	_add_quad_direct(st, transform,
		Vector3(-half_w, panel_height, half_t),
		Vector3(half_w, panel_height, half_t),
		Vector3(half_w, panel_height, -half_t),
		Vector3(-half_w, panel_height, -half_t)
	)

	# Cara Inferior Pilar Izquierdo (-Y)
	_add_quad_direct(st, transform,
		Vector3(-half_w, 0.0, -half_t),
		Vector3(-half_open_w, 0.0, -half_t),
		Vector3(-half_open_w, 0.0, half_t),
		Vector3(-half_w, 0.0, half_t)
	)

	# Cara Inferior Pilar Derecho (-Y)
	_add_quad_direct(st, transform,
		Vector3(half_open_w, 0.0, -half_t),
		Vector3(half_w, 0.0, -half_t),
		Vector3(half_w, 0.0, half_t),
		Vector3(half_open_w, 0.0, half_t)
	)

# ==============================================================================
# 2. ESQUINAS EN L HERMÉTICAS (WATERTIGHT CORNER GEOMETRY)
# ==============================================================================

static func append_corner_top_cornice(
	st: SurfaceTool, arm_length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D,
	notch_width: float = 0.065, notch_depth: float = 0.040, outer_chamfer: float = 0.08
) -> void:
	var w_thick: float = wall_thickness + (trim_overhang * 2.0)
	var w_thin: float = wall_thickness
	var d: float = trim_overhang
	var h_slope: float = clampf(slope_height, 0.02, total_height * 0.45)
	var h_main: float = total_height - h_slope
	var half_h: float = total_height * 0.5

	var y_top: float = half_h
	var y_mid: float = half_h - h_main
	var y_bot: float = -half_h

	var L: float = arm_length
	var c: float = clampf(outer_chamfer, 0.02, w_thick * 0.45)

	var p0 := Vector3(L, 0.0, 0.0)
	var p1 := Vector3(L, 0.0, w_thick)
	var p2 := Vector3(w_thick, 0.0, w_thick)
	var p3 := Vector3(w_thick, 0.0, L)
	var p4 := Vector3(0.0, 0.0, L)
	var p5 := Vector3(0.0, 0.0, c)
	var p6 := Vector3(c, 0.0, 0.0)

	var b0 := Vector3(L, 0.0, d)
	var b1 := Vector3(L, 0.0, w_thick - d)
	var b2 := Vector3(w_thick - d, 0.0, w_thick - d)
	var b3 := Vector3(w_thick - d, 0.0, L)
	var b4 := Vector3(d, 0.0, L)
	var b5 := Vector3(d, 0.0, c + d)
	var b6 := Vector3(c + d, 0.0, d)

	_add_l_polygon_top(st, transform, y_top, p0, p1, p2, p3, p4, p5, p6)

	_add_quad_direct(st, transform, Vector3(p0.x, y_mid, p0.z), Vector3(p6.x, y_mid, p6.z), Vector3(p6.x, y_top, p6.z), Vector3(p0.x, y_top, p0.z))
	_add_quad_direct(st, transform, Vector3(p6.x, y_mid, p6.z), Vector3(p5.x, y_mid, p5.z), Vector3(p5.x, y_top, p5.z), Vector3(p6.x, y_top, p6.z))
	_add_quad_direct(st, transform, Vector3(p5.x, y_mid, p5.z), Vector3(p4.x, y_mid, p4.z), Vector3(p4.x, y_top, p4.z), Vector3(p5.x, y_top, p5.z))

	_add_quad_direct(st, transform, Vector3(p1.x, y_mid, p1.z), Vector3(p1.x, y_top, p1.z), Vector3(p2.x, y_top, p2.z), Vector3(p2.x, y_mid, p2.z))
	_add_quad_direct(st, transform, Vector3(p2.x, y_mid, p2.z), Vector3(p2.x, y_top, p2.z), Vector3(p3.x, y_top, p3.z), Vector3(p3.x, y_mid, p3.z))

	_add_quad_direct(st, transform, Vector3(p0.x, y_bot, b0.z), Vector3(p0.x, y_top, p0.z), Vector3(p1.x, y_top, p1.z), Vector3(p1.x, y_bot, b1.z))
	_add_quad_direct(st, transform, Vector3(p4.x, y_bot, b4.z), Vector3(p3.x, y_bot, b3.z), Vector3(p3.x, y_top, p3.z), Vector3(p4.x, y_top, p4.z))

	_add_quad_direct(st, transform, Vector3(b0.x, y_bot, b0.z), Vector3(b6.x, y_bot, b6.z), Vector3(p6.x, y_mid, p6.z), Vector3(p0.x, y_mid, p0.z))
	_add_quad_direct(st, transform, Vector3(b6.x, y_bot, b6.z), Vector3(b5.x, y_bot, b5.z), Vector3(p5.x, y_mid, p5.z), Vector3(p6.x, y_mid, p6.z))
	_add_quad_direct(st, transform, Vector3(b5.x, y_bot, b5.z), Vector3(b4.x, y_bot, b4.z), Vector3(p4.x, y_mid, p4.z), Vector3(p5.x, y_mid, p5.z))

	_add_quad_direct(st, transform, Vector3(b1.x, y_bot, b1.z), Vector3(p1.x, y_mid, p1.z), Vector3(p2.x, y_mid, p2.z), Vector3(b2.x, y_bot, b2.z))
	_add_quad_direct(st, transform, Vector3(b2.x, y_bot, b2.z), Vector3(p2.x, y_mid, p2.z), Vector3(p3.x, y_mid, p3.z), Vector3(b3.x, y_bot, b3.z))

static func append_corner_bottom_base(
	st: SurfaceTool, arm_length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D,
	notch_width: float = 0.065, notch_depth: float = 0.040, outer_chamfer: float = 0.08
) -> void:
	var w_thick: float = wall_thickness + (trim_overhang * 2.0)
	var w_thin: float = wall_thickness
	var d: float = trim_overhang
	var h_slope: float = clampf(slope_height, 0.02, total_height * 0.45)
	var h_main: float = total_height - h_slope
	var half_h: float = total_height * 0.5

	var y_top: float = half_h
	var y_mid: float = -half_h + h_main
	var y_bot: float = -half_h

	var L: float = arm_length
	var c: float = clampf(outer_chamfer, 0.02, w_thick * 0.45)

	var p0 := Vector3(L, 0.0, 0.0)
	var p1 := Vector3(L, 0.0, w_thick)
	var p2 := Vector3(w_thick, 0.0, w_thick)
	var p3 := Vector3(w_thick, 0.0, L)
	var p4 := Vector3(0.0, 0.0, L)
	var p5 := Vector3(0.0, 0.0, c)
	var p6 := Vector3(c, 0.0, 0.0)

	var b0 := Vector3(L, 0.0, d)
	var b1 := Vector3(L, 0.0, w_thick - d)
	var b2 := Vector3(w_thick - d, 0.0, w_thick - d)
	var b3 := Vector3(w_thick - d, 0.0, L)
	var b4 := Vector3(d, 0.0, L)
	var b5 := Vector3(d, 0.0, c + d)
	var b6 := Vector3(c + d, 0.0, d)

	_add_l_polygon_bottom(st, transform, y_bot, p0, p1, p2, p3, p4, p5, p6)

	_add_quad_direct(st, transform, Vector3(p0.x, y_bot, p0.z), Vector3(p6.x, y_bot, p6.z), Vector3(p6.x, y_mid, p6.z), Vector3(p0.x, y_mid, p0.z))
	_add_quad_direct(st, transform, Vector3(p6.x, y_bot, p6.z), Vector3(p5.x, y_bot, p5.z), Vector3(p5.x, y_mid, p5.z), Vector3(p6.x, y_mid, p6.z))
	_add_quad_direct(st, transform, Vector3(p5.x, y_bot, p5.z), Vector3(p4.x, y_bot, p4.z), Vector3(p4.x, y_mid, p4.z), Vector3(p5.x, y_mid, p5.z))

	_add_quad_direct(st, transform, Vector3(p1.x, y_bot, p1.z), Vector3(p1.x, y_mid, p1.z), Vector3(p2.x, y_mid, p2.z), Vector3(p2.x, y_bot, p2.z))
	_add_quad_direct(st, transform, Vector3(p2.x, y_bot, p2.z), Vector3(p2.x, y_mid, p2.z), Vector3(p3.x, y_mid, p3.z), Vector3(p3.x, y_bot, p3.z))

	_add_quad_direct(st, transform, Vector3(p0.x, y_bot, p0.z), Vector3(p0.x, y_top, b0.z), Vector3(p1.x, y_top, b1.z), Vector3(p1.x, y_bot, p1.z))
	_add_quad_direct(st, transform, Vector3(p4.x, y_bot, p4.z), Vector3(p3.x, y_bot, p3.z), Vector3(p3.x, y_top, b3.z), Vector3(p4.x, y_top, b4.z))

	_add_quad_direct(st, transform, Vector3(p0.x, y_mid, p0.z), Vector3(p6.x, y_mid, p6.z), Vector3(b6.x, y_top, b6.z), Vector3(b0.x, y_top, b0.z))
	_add_quad_direct(st, transform, Vector3(p6.x, y_mid, p6.z), Vector3(p5.x, y_mid, p5.z), Vector3(b5.x, y_top, b5.z), Vector3(b6.x, y_top, b6.z))
	_add_quad_direct(st, transform, Vector3(p5.x, y_mid, p5.z), Vector3(p4.x, y_mid, p4.z), Vector3(b4.x, y_top, b4.z), Vector3(b5.x, y_top, b5.z))

	_add_quad_direct(st, transform, Vector3(p1.x, y_mid, p1.z), Vector3(b1.x, y_top, b1.z), Vector3(b2.x, y_top, b2.z), Vector3(p2.x, y_mid, p2.z))
	_add_quad_direct(st, transform, Vector3(p2.x, y_mid, p2.z), Vector3(b2.x, y_top, b2.z), Vector3(b3.x, y_top, b3.z), Vector3(p3.x, y_mid, p3.z))

static func append_corner_wall_panel(
	st: SurfaceTool, arm_length: float, panel_height: float, wall_thickness: float,
	transform: Transform3D, bevel: float = 0.012, trim_overhang: float = 0.08, outer_chamfer: float = 0.08
) -> void:
	var d: float = trim_overhang
	var L: float = arm_length
	var w_thick: float = wall_thickness + (trim_overhang * 2.0)
	var c: float = clampf(outer_chamfer, 0.02, w_thick * 0.45)
	var half_h: float = panel_height * 0.5

	var y_top: float = half_h
	var y_bot: float = -half_h

	var b0 := Vector3(L, 0.0, d)
	var b1 := Vector3(L, 0.0, w_thick - d)
	var b2 := Vector3(w_thick - d, 0.0, w_thick - d)
	var b3 := Vector3(w_thick - d, 0.0, L)
	var b4 := Vector3(d, 0.0, L)
	var b5 := Vector3(d, 0.0, c + d)
	var b6 := Vector3(c + d, 0.0, d)

	_add_quad_direct(st, transform, Vector3(b0.x, y_bot, b0.z), Vector3(b6.x, y_bot, b6.z), Vector3(b6.x, y_top, b6.z), Vector3(b0.x, y_top, b0.z))
	_add_quad_direct(st, transform, Vector3(b6.x, y_bot, b6.z), Vector3(b5.x, y_bot, b5.z), Vector3(b5.x, y_top, b5.z), Vector3(b6.x, y_top, b6.z))
	_add_quad_direct(st, transform, Vector3(b5.x, y_bot, b5.z), Vector3(b4.x, y_bot, b4.z), Vector3(b4.x, y_top, b4.z), Vector3(b5.x, y_top, b5.z))

	_add_quad_direct(st, transform, Vector3(b1.x, y_bot, b1.z), Vector3(b1.x, y_top, b1.z), Vector3(b2.x, y_top, b2.z), Vector3(b2.x, y_bot, b2.z))
	_add_quad_direct(st, transform, Vector3(b2.x, y_bot, b2.z), Vector3(b2.x, y_top, b2.z), Vector3(b3.x, y_top, b3.z), Vector3(b3.x, y_bot, b3.z))

	_add_quad_direct(st, transform, Vector3(b0.x, y_bot, b0.z), Vector3(b0.x, y_top, b0.z), Vector3(b1.x, y_top, b1.z), Vector3(b1.x, y_bot, b1.z))
	_add_quad_direct(st, transform, Vector3(b4.x, y_bot, b4.z), Vector3(b3.x, y_bot, b3.z), Vector3(b3.x, y_top, b3.z), Vector3(b4.x, y_top, b4.z))

# ==============================================================================
# 3. PIEZAS RECTAS (WALL PROCEDURAL GEOMETRY)
# ==============================================================================

static func append_top_cornice(
	st: SurfaceTool, length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D, bevel: float = 0.018
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
	_add_polygon_5(st, transform, Vector3(half_len, y_bot, half_w_thin), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_top, half_w_thick), Vector3(half_len, y_top, -half_w_thick), Vector3(half_len, y_mid, -half_w_thick), Vector3(half_len, y_bot, -half_w_thin))
	_add_polygon_5(st, transform, Vector3(-half_len, y_bot, -half_w_thin), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_top, -half_w_thick), Vector3(-half_len, y_top, half_w_thick), Vector3(-half_len, y_mid, half_w_thick), Vector3(-half_len, y_bot, half_w_thin))

static func append_bottom_base(
	st: SurfaceTool, length: float, total_height: float, slope_height: float,
	wall_thickness: float, trim_overhang: float, transform: Transform3D, bevel: float = 0.018
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
	_add_polygon_5(st, transform, Vector3(half_len, y_bot, -half_w_thick), Vector3(half_len, y_mid, -half_w_thick), Vector3(half_len, y_top, -half_w_thin), Vector3(half_len, y_top, half_w_thin), Vector3(half_len, y_mid, half_w_thick), Vector3(half_len, y_bot, half_w_thick))
	_add_polygon_5(st, transform, Vector3(-half_len, y_bot, half_w_thick), Vector3(-half_len, y_mid, half_w_thick), Vector3(-half_len, y_top, half_w_thin), Vector3(-half_len, y_top, -half_w_thin), Vector3(-half_len, y_mid, -half_w_thick), Vector3(-half_len, y_bot, -half_w_thick))

static func append_modular_top_trim(
	st: SurfaceTool, total_length: float, segment_length: float, total_height: float,
	slope_height: float, wall_thickness: float, trim_overhang: float, transform: Transform3D,
	notch_width: float = 0.065, notch_depth: float = 0.040
) -> void:
	var num_segs: int = maxi(1, int(round(total_length / segment_length)))
	var actual_seg_len: float = total_length / float(num_segs)

	for i in range(num_segs):
		var seg_center_x: float = (float(i) * actual_seg_len) + (actual_seg_len * 0.5) - (total_length * 0.5)
		var block_w: float = actual_seg_len - (notch_width if num_segs > 1 else notch_width * 0.5)

		if num_segs == 1:
			var half_b: float = (actual_seg_len * 0.5) - (notch_width * 0.5)
			var left_x: float = -(notch_width * 0.5 + (half_b * 0.5))
			var right_x: float = notch_width * 0.5 + (half_b * 0.5)
			var t_l := transform * Transform3D(Basis(), Vector3(left_x, 0.0, 0.0))
			append_top_cornice(st, half_b, total_height, slope_height, wall_thickness, trim_overhang, t_l)
			var t_r := transform * Transform3D(Basis(), Vector3(right_x, 0.0, 0.0))
			append_top_cornice(st, half_b, total_height, slope_height, wall_thickness, trim_overhang, t_r)
		else:
			var t := transform * Transform3D(Basis(), Vector3(seg_center_x, 0.0, 0.0))
			append_top_cornice(st, block_w, total_height, slope_height, wall_thickness, trim_overhang, t)

static func append_modular_bottom_base(
	st: SurfaceTool, total_length: float, segment_length: float, total_height: float,
	slope_height: float, wall_thickness: float, trim_overhang: float, transform: Transform3D,
	notch_width: float = 0.065, notch_depth: float = 0.040
) -> void:
	var num_segs: int = maxi(1, int(round(total_length / segment_length)))
	var actual_seg_len: float = total_length / float(num_segs)

	for i in range(num_segs):
		var seg_center_x: float = (float(i) * actual_seg_len) + (actual_seg_len * 0.5) - (total_length * 0.5)
		var block_w: float = actual_seg_len - (notch_width if num_segs > 1 else notch_width * 0.5)

		if num_segs == 1:
			var half_b: float = (actual_seg_len * 0.5) - (notch_width * 0.5)
			var left_x: float = -(notch_width * 0.5 + (half_b * 0.5))
			var right_x: float = notch_width * 0.5 + (half_b * 0.5)
			var t_l := transform * Transform3D(Basis(), Vector3(left_x, 0.0, 0.0))
			append_bottom_base(st, half_b, total_height, slope_height, wall_thickness, trim_overhang, t_l)
			var t_r := transform * Transform3D(Basis(), Vector3(right_x, 0.0, 0.0))
			append_bottom_base(st, half_b, total_height, slope_height, wall_thickness, trim_overhang, t_r)
		else:
			var t := transform * Transform3D(Basis(), Vector3(seg_center_x, 0.0, 0.0))
			append_bottom_base(st, block_w, total_height, slope_height, wall_thickness, trim_overhang, t)

# ==============================================================================
# 4. LADRILLOS ESTILIZADOS
# ==============================================================================

static func append_pillowed_brick(
	st: SurfaceTool, size: Vector3, transform: Transform3D, bevel: float = 0.028, uv_scale: Vector2 = Vector2.ONE
) -> void:
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
	_add_quad_direct(st, transform, Vector3(-ix, -iy, -hz), Vector3(ix, -iy, -hz), Vector3(ix, -hy, -iz), Vector3(-ix, -hy, -iz))

	_add_quad_direct(st, transform, Vector3(ix, -iy, hz), Vector3(hx, -iy, iz), Vector3(hx, iy, iz), Vector3(ix, iy, hz))
	_add_quad_direct(st, transform, Vector3(-hx, -iy, iz), Vector3(-ix, -iy, hz), Vector3(-ix, iy, hz), Vector3(-hx, iy, iz))
	_add_quad_direct(st, transform, Vector3(hx, -iy, -iz), Vector3(ix, -iy, -hz), Vector3(ix, iy, -hz), Vector3(hx, iy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, -iy, -hz), Vector3(-hx, -iy, -iz), Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz))

	_add_quad_direct(st, transform, Vector3(ix, hy, iz), Vector3(hx, iy, iz), Vector3(hx, iy, -iz), Vector3(ix, hy, -iz))
	_add_quad_direct(st, transform, Vector3(hx, -iy, iz), Vector3(ix, -hy, iz), Vector3(ix, -hy, -iz), Vector3(hx, -iy, -iz))
	_add_quad_direct(st, transform, Vector3(-hx, iy, iz), Vector3(-ix, hy, iz), Vector3(-ix, hy, -iz), Vector3(-hx, iy, -iz))
	_add_quad_direct(st, transform, Vector3(-ix, -hy, iz), Vector3(-hx, -iy, iz), Vector3(-hx, -iy, -iz), Vector3(-ix, -hy, -iz))

static func append_beveled_box(st: SurfaceTool, size: Vector3, transform: Transform3D, bevel: float = 0.015, uv_scale: Vector2 = Vector2.ONE) -> void:
	append_pillowed_brick(st, size, transform, bevel, uv_scale)

# ==============================================================================
# HELPERS DE TRIANGULACIÓN
# ==============================================================================

static func _add_l_polygon_top(st: SurfaceTool, transform: Transform3D, y: float, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, p5: Vector3, p6: Vector3) -> void:
	var v0 := Vector3(p0.x, y, p0.z)
	var v1 := Vector3(p1.x, y, p1.z)
	var v2 := Vector3(p2.x, y, p2.z)
	var v3 := Vector3(p3.x, y, p3.z)
	var v4 := Vector3(p4.x, y, p4.z)
	var v5 := Vector3(p5.x, y, p5.z)
	var v6 := Vector3(p6.x, y, p6.z)

	_add_triangle_direct(st, transform, v2, v3, v4)
	_add_triangle_direct(st, transform, v2, v4, v5)
	_add_triangle_direct(st, transform, v2, v5, v6)
	_add_triangle_direct(st, transform, v2, v6, v0)
	_add_triangle_direct(st, transform, v2, v0, v1)

static func _add_l_polygon_bottom(st: SurfaceTool, transform: Transform3D, y: float, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, p5: Vector3, p6: Vector3) -> void:
	var v0 := Vector3(p0.x, y, p0.z)
	var v1 := Vector3(p1.x, y, p1.z)
	var v2 := Vector3(p2.x, y, p2.z)
	var v3 := Vector3(p3.x, y, p3.z)
	var v4 := Vector3(p4.x, y, p4.z)
	var v5 := Vector3(p5.x, y, p5.z)
	var v6 := Vector3(p6.x, y, p6.z)

	_add_triangle_direct(st, transform, v2, v4, v3)
	_add_triangle_direct(st, transform, v2, v5, v4)
	_add_triangle_direct(st, transform, v2, v6, v5)
	_add_triangle_direct(st, transform, v2, v0, v6)
	_add_triangle_direct(st, transform, v2, v1, v0)

static func _add_polygon_5(st: SurfaceTool, transform: Transform3D, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, v5: Vector3) -> void:
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
