# TorchGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de alta fidelidad para antorchas estilizadas (Brazier / Jaula Gótica).
## Recrea con exactitud la topología de 8 lados (octogonal), el eje biselado, la abrazadera de montaje con soporte de pared,
## la copa/cáliz acampanado, el aro perimetral y las 4 garfas/costillas en corona de hierro forjado.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_torch_fixture(scale_mult: float = 1.0, flame_scale: float = 1.0):
	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"gothic_torch_fixture"

	# ==========================================================================
	# 1. SOPORTE DE HIERRO FORJADO COMPLETO (GOTHIC BRAZIER)
	# ==========================================================================
	var g_bracket = _GeneratedMeshScript.new()
	g_bracket.component_id = 0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Angulación de los 8 lados (octógono)
	var num_sides: int = 8
	var angles: Array[float] = []
	for i in range(num_sides):
		angles.append(float(i) * (TAU / float(num_sides)))

	# --------------------------------------------------------------------------
	# A. PUNTA INFERIOR Y EJE OCTOGONAL (LOWER SHAFT)
	# --------------------------------------------------------------------------
	var y_tip: float = -0.32 * scale_mult
	var y_shaft_bot: float = -0.25 * scale_mult
	var y_collar_bot: float = -0.07 * scale_mult
	var r_tip: float = 0.016 * scale_mult
	var r_shaft: float = 0.032 * scale_mult

	# Tapa inferior de la punta
	_build_octagonal_cap(st, y_tip, r_tip, angles, false)
	# Cono de la punta
	_build_octagonal_frustum(st, y_tip, y_shaft_bot, r_tip, r_shaft, angles)
	# Eje inferior
	_build_octagonal_frustum(st, y_shaft_bot, y_collar_bot, r_shaft, r_shaft, angles)

	# --------------------------------------------------------------------------
	# B. ABRAZADERA / ANILLO DE MONTAJE (COLLAR) Y SOPORTE DE PARED (WALL MOUNT)
	# --------------------------------------------------------------------------
	var y_col_chamfer_bot: float = -0.05 * scale_mult
	var y_col_chamfer_top: float = -0.01 * scale_mult
	var y_collar_top: float = 0.01 * scale_mult
	var r_collar: float = 0.048 * scale_mult

	# Bisel inferior del collar
	_build_octagonal_frustum(st, y_collar_bot, y_col_chamfer_bot, r_shaft, r_collar, angles)
	# Cuerpo cilíndrico del collar
	_build_octagonal_frustum(st, y_col_chamfer_bot, y_col_chamfer_top, r_collar, r_collar, angles)
	# Bisel superior del collar
	_build_octagonal_frustum(st, y_col_chamfer_top, y_collar_top, r_collar, r_shaft, angles)

	# Brazo y brida de montaje hacia la pared (-Z)
	var arm_w: float = 0.035 * scale_mult
	var arm_h: float = 0.040 * scale_mult
	var arm_z_front: float = -0.035 * scale_mult
	var arm_z_back: float = -0.16 * scale_mult
	_build_box(st,
		Vector3(-arm_w * 0.5, y_col_chamfer_bot + 0.005, arm_z_back),
		Vector3(arm_w * 0.5, y_col_chamfer_top - 0.005, arm_z_front)
	)
	# Brida de pared plana
	var flange_w: float = 0.08 * scale_mult
	var flange_h: float = 0.09 * scale_mult
	var flange_t: float = 0.015 * scale_mult
	_build_box(st,
		Vector3(-flange_w * 0.5, y_col_chamfer_bot - 0.02, arm_z_back - flange_t),
		Vector3(flange_w * 0.5, y_col_chamfer_top + 0.02, arm_z_back)
	)

	# --------------------------------------------------------------------------
	# C. CUELLO SUPERIOR Y CÁLIZ ACAMPANADO (BASKET BASE)
	# --------------------------------------------------------------------------
	var y_neck_top: float = 0.08 * scale_mult
	var y_cup_top: float = 0.16 * scale_mult
	var r_cup_top: float = 0.090 * scale_mult

	# Cuello octogonal
	_build_octagonal_frustum(st, y_collar_top, y_neck_top, r_shaft, r_shaft, angles)
	# Expansión cónica del cáliz
	_build_octagonal_frustum(st, y_neck_top, y_cup_top, r_shaft, r_cup_top, angles)
	# Fondo interior del cáliz (piso de la canasta)
	_build_octagonal_cap(st, y_cup_top, r_cup_top, angles, true)

	# --------------------------------------------------------------------------
	# D. ARO PERIMETRAL / ZUNCHO INTERMEDIO (OCTAGONAL HOOP)
	# --------------------------------------------------------------------------
	var y_hoop_bot: float = 0.24 * scale_mult
	var y_hoop_top: float = 0.28 * scale_mult
	var r_hoop_out: float = 0.105 * scale_mult
	var r_hoop_in: float = 0.085 * scale_mult

	_build_octagonal_hoop(st, y_hoop_bot, y_hoop_top, r_hoop_out, r_hoop_in, angles)

	# --------------------------------------------------------------------------
	# E. LAS 4 COSTILLAS EN CORONA GÓTICA (4 CROWN PRONGS / RIBS)
	# --------------------------------------------------------------------------
	# Colocadas a 0°, 90°, 180°, 270° (N, S, E, W)
	var prong_w: float = 0.032 * scale_mult
	var prong_d: float = 0.024 * scale_mult
	var prong_angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]

	for pa in prong_angles:
		var y0: float = 0.12 * scale_mult
		var y1: float = 0.38 * scale_mult
		var r0: float = 0.075 * scale_mult
		var r1: float = 0.118 * scale_mult # Inclinación outward hacia la cima

		_build_tapered_rib(st, y0, y1, r0, r1, prong_w, prong_d, pa)

	# --------------------------------------------------------------------------
	# COMMIT DEL SOPORTE DE HIERRO
	# --------------------------------------------------------------------------
	st.generate_tangents()
	var bracket_mesh := ArrayMesh.new()
	bracket_mesh = st.commit(bracket_mesh)
	g_bracket.mesh = bracket_mesh
	g_bracket.bounds = AABB(
		Vector3(-0.15, -0.35, -0.20) * scale_mult,
		Vector3(0.30, 0.75, 0.40) * scale_mult
	)
	g_bracket.material_slots[0] = _WallMaterialFactoryScript.create_iron_material()

	var bracket_xform := Transform3D.IDENTITY
	bracket_xform.basis = Basis(Vector3.RIGHT, deg_to_rad(14.0)) # Inclinación 14° hacia adelante
	bracket_xform.origin = Vector3(0.0, 0.0, 0.06 * scale_mult)
	asset.add_mesh(&"bracket", g_bracket, bracket_xform)

	# ==========================================================================
	# 2. LLAMA 3D ESTILIZADA PROCEDURAL (FLAME)
	# ==========================================================================
	var g_flame = _GeneratedMeshScript.new()
	g_flame.component_id = 1

	var st_flame := SurfaceTool.new()
	st_flame.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_stylized_flame_geometry(st_flame, 0.08 * flame_scale, 0.22 * flame_scale)
	st_flame.generate_tangents()

	var flame_mesh := ArrayMesh.new()
	flame_mesh = st_flame.commit(flame_mesh)
	g_flame.mesh = flame_mesh
	g_flame.bounds = AABB(Vector3(-0.08, -0.05, -0.08) * flame_scale, Vector3(0.16, 0.25, 0.16) * flame_scale)

	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.85, 0.45, 1.0)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.58, 0.12)
	flame_mat.emission_energy_multiplier = 6.5
	flame_mat.roughness = 0.2
	g_flame.material_slots[0] = flame_mat

	var flame_xform := Transform3D.IDENTITY
	flame_xform.origin = Vector3(0.0, 0.20 * scale_mult, 0.11 * scale_mult)
	asset.add_mesh(&"flame", g_flame, flame_xform)

	return asset

# ==============================================================================
# CONSTRUCTORES GEOMÉTRICOS AUXILIARES
# ==============================================================================

static func _build_octagonal_frustum(
	st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, angles: Array[float]
) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p2 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var p3 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)

		_add_quad_smooth(st, p0, p1, p2, p3)

static func _build_octagonal_cap(
	st: SurfaceTool, y: float, r: float, angles: Array[float], pointing_up: bool
) -> void:
	var center := Vector3(0.0, y, 0.0)
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var p0 := Vector3(cos(angles[i]) * r, y, sin(angles[i]) * r)
		var p1 := Vector3(cos(angles[i_next]) * r, y, sin(angles[i_next]) * r)

		if pointing_up:
			_add_triangle_direct(st, center, p0, p1)
		else:
			_add_triangle_direct(st, center, p1, p0)

static func _build_octagonal_hoop(
	st: SurfaceTool, y_bot: float, y_top: float, r_out: float, r_in: float, angles: Array[float]
) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		# Vértices exteriores
		var po0 := Vector3(cos(a0) * r_out, y_bot, sin(a0) * r_out)
		var po1 := Vector3(cos(a1) * r_out, y_bot, sin(a1) * r_out)
		var po2 := Vector3(cos(a1) * r_out, y_top, sin(a1) * r_out)
		var po3 := Vector3(cos(a0) * r_out, y_top, sin(a0) * r_out)

		# Vértices interiores
		var pi0 := Vector3(cos(a0) * r_in, y_bot, sin(a0) * r_in)
		var pi1 := Vector3(cos(a1) * r_in, y_bot, sin(a1) * r_in)
		var pi2 := Vector3(cos(a1) * r_in, y_top, sin(a1) * r_in)
		var pi3 := Vector3(cos(a0) * r_in, y_top, sin(a0) * r_in)

		# Cara exterior
		_add_quad_direct(st, po0, po1, po2, po3)
		# Cara interior
		_add_quad_direct(st, pi1, pi0, pi3, pi2)
		# Borde superior
		_add_quad_direct(st, po3, po2, pi2, pi3)
		# Borde inferior
		_add_quad_direct(st, po1, po0, pi0, pi1)

static func _build_tapered_rib(
	st: SurfaceTool, y0: float, y1: float, r0: float, r1: float,
	width: float, depth: float, angle: float
) -> void:
	var rot := Basis(Vector3.UP, angle)
	var hw: float = width * 0.5
	var hd: float = depth * 0.5

	# Base de la costilla
	var p0_loc := Vector3(-hw, y0, r0 - hd)
	var p1_loc := Vector3(hw, y0, r0 - hd)
	var p2_loc := Vector3(hw, y0, r0 + hd)
	var p3_loc := Vector3(-hw, y0, r0 + hd)

	# Cima de la costilla
	var p4_loc := Vector3(-hw, y1, r1 - hd)
	var p5_loc := Vector3(hw, y1, r1 - hd)
	var p6_loc := Vector3(hw, y1, r1 + hd)
	var p7_loc := Vector3(-hw, y1, r1 + hd)

	# Transformar al ángulo respectivo
	var v0: Vector3 = rot * p0_loc
	var v1: Vector3 = rot * p1_loc
	var v2: Vector3 = rot * p2_loc
	var v3: Vector3 = rot * p3_loc
	var v4: Vector3 = rot * p4_loc
	var v5: Vector3 = rot * p5_loc
	var v6: Vector3 = rot * p6_loc
	var v7: Vector3 = rot * p7_loc

	# Cara frontal exterior (+Z relativo)
	_add_quad_direct(st, v3, v2, v6, v7)
	# Cara trasera interior (-Z relativo)
	_add_quad_direct(st, v1, v0, v4, v5)
	# Lateral derecho (+X relativo)
	_add_quad_direct(st, v2, v1, v5, v6)
	# Lateral izquierdo (-X relativo)
	_add_quad_direct(st, v0, v3, v7, v4)
	# Cima biselada
	_add_quad_direct(st, v7, v6, v5, v4)
	# Fondo
	_add_quad_direct(st, v0, v1, v2, v3)

static func _build_box(st: SurfaceTool, min_v: Vector3, max_v: Vector3) -> void:
	var p0 := Vector3(min_v.x, min_v.y, max_v.z)
	var p1 := Vector3(max_v.x, min_v.y, max_v.z)
	var p2 := Vector3(max_v.x, max_v.y, max_v.z)
	var p3 := Vector3(min_v.x, max_v.y, max_v.z)

	var p4 := Vector3(min_v.x, min_v.y, min_v.z)
	var p5 := Vector3(max_v.x, min_v.y, min_v.z)
	var p6 := Vector3(max_v.x, max_v.y, min_v.z)
	var p7 := Vector3(min_v.x, max_v.y, min_v.z)

	_add_quad_direct(st, p0, p1, p2, p3) # Front
	_add_quad_direct(st, p5, p4, p7, p6) # Back
	_add_quad_direct(st, p1, p5, p6, p2) # Right
	_add_quad_direct(st, p4, p0, p3, p7) # Left
	_add_quad_direct(st, p3, p2, p6, p7) # Top
	_add_quad_direct(st, p4, p5, p1, p0) # Bottom

static func _build_stylized_flame_geometry(st: SurfaceTool, radius: float, height: float) -> void:
	var segs: int = 12
	var rings: int = 6

	var prev_ring: Array[Vector3] = []
	for r in range(rings + 1):
		var v_frac: float = float(r) / float(rings)
		var y: float = v_frac * height
		# Perfil de gota: se ensancha en el primer tercio y se afila en la punta
		var r_curr: float = sin(v_frac * PI) * radius
		if v_frac > 0.6:
			r_curr *= (1.0 - ((v_frac - 0.6) / 0.4))

		var curr_ring: Array[Vector3] = []
		for s in range(segs):
			var u_frac: float = float(s) / float(segs)
			var a: float = u_frac * TAU
			curr_ring.append(Vector3(cos(a) * r_curr, y, sin(a) * r_curr))

		if r > 0:
			for s in range(segs):
				var s_next: int = (s + 1) % segs
				var p0: Vector3 = prev_ring[s]
				var p1: Vector3 = prev_ring[s_next]
				var p2: Vector3 = curr_ring[s_next]
				var p3: Vector3 = curr_ring[s]
				_add_quad_smooth(st, p0, p1, p2, p3)

		prev_ring = curr_ring

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

static func _add_quad_smooth(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var n0: Vector3 = Vector3(p0.x, 0.0, p0.z).normalized()
	var n1: Vector3 = Vector3(p1.x, 0.0, p1.z).normalized()
	var n2: Vector3 = Vector3(p2.x, 0.0, p2.z).normalized()
	var n3: Vector3 = Vector3(p3.x, 0.0, p3.z).normalized()

	st.set_normal(n0)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(n1)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)

	st.set_normal(n2)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(n0)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(n2)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(n3)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p3)
