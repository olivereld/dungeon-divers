class_name DoorGeometryBuilder
extends RefCounted

## Generador procedural de geometría 3D para hojas de puerta estilizadas (Fase 9).
## Construye:
## 1. Superficie "DoorWood": 3 tablones verticales arqueados con ranuras en V y 2 travesaños horizontales biselados.
## 2. Superficie "DoorIron": Aldaba de hierro forjado con soporte de gancho y argolla toroidal colgante.

## Construye la geometría completa de la hoja de puerta alineada con un offset de centro arbitrario.
static func build_door_leaf_surfaces(
	st_wood: SurfaceTool,
	st_iron: SurfaceTool,
	config: WallMeshConfig,
	center_offset: Vector3 = Vector3.ZERO
) -> void:
	var total_w: float = config.door_width
	var total_h: float = config.door_height
	var thickness: float = config.door_thickness
	var num_planks: int = maxi(2, config.door_plank_count)
	var batten_depth: float = config.door_batten_depth

	var center_x: float = center_offset.x
	var base_y: float = center_offset.y
	var center_z: float = center_offset.z

	var half_w: float = total_w * 0.5
	var half_d: float = thickness * 0.5
	var arch_radius: float = half_w
	var spring_y: float = base_y + maxf(0.5, total_h - arch_radius)

	# 1. GENERAR LOS TABLONES VERTICALES (WOOD)
	var plank_w: float = total_w / float(num_planks)
	var bevel: float = 0.015
	var seam_gap: float = 0.006

	for p in range(num_planks):
		var p_min_x: float = center_x - half_w + (float(p) * plank_w) + (seam_gap * 0.5)
		var p_max_x: float = center_x - half_w + (float(p + 1) * plank_w) - (seam_gap * 0.5)
		_build_arched_plank(st_wood, p_min_x, p_max_x, spring_y, arch_radius, half_d, bevel, center_x, base_y, center_z)

	# 2. GENERAR LOS DOS TRAVESAÑOS HORIZONTALES (WOOD - Delantero y Trasero)
	var batten_h: float = 0.22
	var batten_w: float = total_w - 0.04
	var upper_y: float = spring_y - 0.28
	var lower_y: float = base_y + 0.52

	# Delantero (+Z)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, upper_y - batten_h * 0.5, upper_y + batten_h * 0.5, center_z + half_d, center_z + half_d + batten_depth, 0.018)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, lower_y - batten_h * 0.5, lower_y + batten_h * 0.5, center_z + half_d, center_z + half_d + batten_depth, 0.018)

	# Trasero (-Z)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, upper_y - batten_h * 0.5, upper_y + batten_h * 0.5, center_z - half_d - batten_depth, center_z - half_d, 0.018)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, lower_y - batten_h * 0.5, lower_y + batten_h * 0.5, center_z - half_d - batten_depth, center_z - half_d, 0.018)

	# 3. GENERAR LA ALDABA DE HIERRO (IRON - Delantera y Trasera)
	var knocker_x: float = center_x - total_w * 0.22
	var knocker_y: float = (upper_y + lower_y) * 0.5
	var knocker_r: float = config.door_knocker_radius

	# Aldaba frontal
	_build_iron_knocker(st_iron, Vector3(knocker_x, knocker_y, center_z + half_d), knocker_r, 1.0)
	# Aldaba trasera
	_build_iron_knocker(st_iron, Vector3(knocker_x, knocker_y, center_z - half_d), knocker_r, -1.0)

## Construye un tablón vertical individual con remate arqueado superior y biseles perimetrales.
static func _build_arched_plank(
	st: SurfaceTool,
	min_x: float,
	max_x: float,
	spring_y: float,
	arch_radius: float,
	half_d: float,
	bevel: float,
	center_x: float,
	base_y: float,
	center_z: float
) -> void:
	var num_segs: int = 6
	var step_x: float = (max_x - min_x) / float(num_segs)

	# Calcular los puntos del perfil superior curvado respecto al centro del arco
	var top_pts: Array[Vector2] = []
	for i in range(num_segs + 1):
		var x: float = min_x + (float(i) * step_x)
		var rel_x: float = x - center_x
		var rad_sq: float = (arch_radius * arch_radius) - (rel_x * rel_x)
		var y: float = spring_y + (sqrt(maxf(0.0, rad_sq)))
		top_pts.append(Vector2(x, y))

	# Cara Frontal (+Z) con bisel
	var front_z: float = center_z + half_d
	var back_z: float = center_z - half_d

	# Quads de la cara frontal
	for i in range(num_segs):
		var x0: float = top_pts[i].x
		var x1: float = top_pts[i + 1].x
		var y0: float = top_pts[i].y
		var y1: float = top_pts[i + 1].y

		# Panel frontal central
		_add_quad(st,
			Vector3(x0, base_y, front_z),
			Vector3(x1, base_y, front_z),
			Vector3(x1, y1 - bevel, front_z),
			Vector3(x0, y0 - bevel, front_z)
		)

		# Bisel superior
		_add_quad(st,
			Vector3(x0, y0 - bevel, front_z),
			Vector3(x1, y1 - bevel, front_z),
			Vector3(x1, y1, front_z - bevel),
			Vector3(x0, y0, front_z - bevel)
		)

	# Cara Trasera (-Z)
	for i in range(num_segs):
		var x0: float = top_pts[i].x
		var x1: float = top_pts[i + 1].x
		var y0: float = top_pts[i].y
		var y1: float = top_pts[i + 1].y

		_add_quad(st,
			Vector3(x1, base_y, back_z),
			Vector3(x0, base_y, back_z),
			Vector3(x0, y0 - bevel, back_z),
			Vector3(x1, y1 - bevel, back_z)
		)

		_add_quad(st,
			Vector3(x1, y1 - bevel, back_z),
			Vector3(x0, y0 - bevel, back_z),
			Vector3(x0, y0, back_z + bevel),
			Vector3(x1, y1, back_z + bevel)
		)

	# Lateral Izquierdo (-X)
	var top_y_left: float = top_pts[0].y
	_add_quad(st,
		Vector3(min_x, base_y, back_z),
		Vector3(min_x, base_y, front_z),
		Vector3(min_x, top_y_left, front_z),
		Vector3(min_x, top_y_left, back_z)
	)

	# Lateral Derecho (+X)
	var top_y_right: float = top_pts[num_segs].y
	_add_quad(st,
		Vector3(max_x, base_y, front_z),
		Vector3(max_x, base_y, back_z),
		Vector3(max_x, top_y_right, back_z),
		Vector3(max_x, top_y_right, front_z)
	)

	# Borde Superior Arqueado (+Y)
	for i in range(num_segs):
		var p0: Vector2 = top_pts[i]
		var p1: Vector2 = top_pts[i + 1]
		_add_quad(st,
			Vector3(p0.x, p0.y, front_z),
			Vector3(p1.x, p1.y, front_z),
			Vector3(p1.x, p1.y, back_z),
			Vector3(p0.x, p0.y, back_z)
		)

	# Fondo Inferior (Y = base_y)
	_add_quad(st,
		Vector3(min_x, base_y, front_z),
		Vector3(min_x, base_y, back_z),
		Vector3(max_x, base_y, back_z),
		Vector3(max_x, base_y, front_z)
	)

## Construye un travesaño horizontal biselado.
static func _build_beveled_batten(
	st: SurfaceTool,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	min_z: float,
	max_z: float,
	bevel: float
) -> void:
	var b_y: float = minf(bevel, (max_y - min_y) * 0.25)
	var b_x: float = minf(bevel, 0.02)
	var b_z: float = minf(bevel, absf(max_z - min_z) * 0.4)

	var is_front: bool = max_z > 0.0

	if is_front:
		# Cara frontal
		_add_quad(st,
			Vector3(min_x + b_x, min_y + b_y, max_z),
			Vector3(max_x - b_x, min_y + b_y, max_z),
			Vector3(max_x - b_x, max_y - b_y, max_z),
			Vector3(min_x + b_x, max_y - b_y, max_z)
		)
		# Bisel superior
		_add_quad(st,
			Vector3(min_x + b_x, max_y - b_y, max_z),
			Vector3(max_x - b_x, max_y - b_y, max_z),
			Vector3(max_x, max_y, min_z),
			Vector3(min_x, max_y, min_z)
		)
		# Bisel inferior
		_add_quad(st,
			Vector3(min_x, min_y, min_z),
			Vector3(max_x, min_y, min_z),
			Vector3(max_x - b_x, min_y + b_y, max_z),
			Vector3(min_x + b_x, min_y + b_y, max_z)
		)
		# Bisel izquierdo
		_add_quad(st,
			Vector3(min_x, min_y, min_z),
			Vector3(min_x + b_x, min_y + b_y, max_z),
			Vector3(min_x + b_x, max_y - b_y, max_z),
			Vector3(min_x, max_y, min_z)
		)
		# Bisel derecho
		_add_quad(st,
			Vector3(max_x - b_x, min_y + b_y, max_z),
			Vector3(max_x, min_y, min_z),
			Vector3(max_x, max_y, min_z),
			Vector3(max_x - b_x, max_y - b_y, max_z)
		)
	else:
		# Cara trasera (-Z)
		_add_quad(st,
			Vector3(max_x - b_x, min_y + b_y, min_z),
			Vector3(min_x + b_x, min_y + b_y, min_z),
			Vector3(min_x + b_x, max_y - b_y, min_z),
			Vector3(max_x - b_x, max_y - b_y, min_z)
		)
		# Bisel superior
		_add_quad(st,
			Vector3(max_x, max_y, max_z),
			Vector3(min_x, max_y, max_z),
			Vector3(min_x + b_x, max_y - b_y, min_z),
			Vector3(max_x - b_x, max_y - b_y, min_z)
		)
		# Bisel inferior
		_add_quad(st,
			Vector3(max_x - b_x, min_y + b_y, min_z),
			Vector3(min_x + b_x, min_y + b_y, min_z),
			Vector3(min_x, min_y, max_z),
			Vector3(max_x, min_y, max_z)
		)
		# Bisel izquierdo
		_add_quad(st,
			Vector3(min_x + b_x, min_y + b_y, min_z),
			Vector3(min_x, min_y, max_z),
			Vector3(min_x, max_y, max_z),
			Vector3(min_x + b_x, max_y - b_y, min_z)
		)
		# Bisel derecho
		_add_quad(st,
			Vector3(max_x, min_y, max_z),
			Vector3(max_x - b_x, min_y + b_y, min_z),
			Vector3(max_x - b_x, max_y - b_y, min_z),
			Vector3(max_x, max_y, max_z)
		)

## Construye la aldaba de hierro compuesta por el soporte y la argolla toroidal.
static func _build_iron_knocker(
	st: SurfaceTool,
	base_pos: Vector3,
	ring_radius: float,
	dir_z: float
) -> void:
	var mount_r: float = 0.016
	var mount_reach: float = 0.052

	# 1. Soporte en U (Bracket Hook)
	_build_cylinder_segment(st, base_pos + Vector3(0.0, ring_radius * 0.75, 0.0), base_pos + Vector3(0.0, ring_radius * 0.75, dir_z * mount_reach), mount_r, 8)
	_build_cylinder_segment(st, base_pos + Vector3(0.0, ring_radius * 0.75, dir_z * mount_reach), base_pos + Vector3(0.0, ring_radius * 0.45, dir_z * mount_reach), mount_r, 8)

	# 2. Argolla Toroidal (Torus Ring)
	var ring_center := base_pos + Vector3(0.0, 0.0, dir_z * mount_reach)
	var major_r: float = ring_radius
	var minor_r: float = 0.018
	var major_segs: int = 14
	var minor_segs: int = 8

	_build_torus(st, ring_center, major_r, minor_r, major_segs, minor_segs, dir_z)

## Construye un toroide estilizado faceted.
static func _build_torus(
	st: SurfaceTool,
	center: Vector3,
	major_r: float,
	minor_r: float,
	major_segs: int,
	minor_segs: int,
	dir_z: float
) -> void:
	for i in range(major_segs):
		var phi0: float = (float(i) / float(major_segs)) * TAU
		var phi1: float = (float(i + 1) / float(major_segs)) * TAU

		var c0 := Vector3(cos(phi0) * major_r, sin(phi0) * major_r, 0.0)
		var c1 := Vector3(cos(phi1) * major_r, sin(phi1) * major_r, 0.0)

		for j in range(minor_segs):
			var theta0: float = (float(j) / float(minor_segs)) * TAU
			var theta1: float = (float(j + 1) / float(minor_segs)) * TAU

			var p00 := center + c0 + Vector3(cos(phi0) * cos(theta0) * minor_r, sin(phi0) * cos(theta0) * minor_r, sin(theta0) * minor_r)
			var p01 := center + c0 + Vector3(cos(phi0) * cos(theta1) * minor_r, sin(phi0) * cos(theta1) * minor_r, sin(theta1) * minor_r)
			var p10 := center + c1 + Vector3(cos(phi1) * cos(theta0) * minor_r, sin(phi1) * cos(theta0) * minor_r, sin(theta0) * minor_r)
			var p11 := center + c1 + Vector3(cos(phi1) * cos(theta1) * minor_r, sin(phi1) * cos(theta1) * minor_r, sin(theta1) * minor_r)

			if dir_z > 0.0:
				_add_quad(st, p00, p10, p11, p01)
			else:
				_add_quad(st, p00, p01, p11, p10)

## Construye un segmento de cilindro orientado.
static func _build_cylinder_segment(
	st: SurfaceTool,
	start_p: Vector3,
	end_p: Vector3,
	radius: float,
	segs: int
) -> void:
	var axis := (end_p - start_p).normalized()
	var perp := Vector3.UP.cross(axis)
	if perp.length_squared() < 0.01:
		perp = Vector3.RIGHT.cross(axis)
	perp = perp.normalized() * radius
	var perp2 := axis.cross(perp).normalized() * radius

	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU

		var off0 := (perp * cos(a0)) + (perp2 * sin(a0))
		var off1 := (perp * cos(a1)) + (perp2 * sin(a1))

		_add_quad(st,
			start_p + off0,
			start_p + off1,
			end_p + off1,
			end_p + off0
		)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
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

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p3)
