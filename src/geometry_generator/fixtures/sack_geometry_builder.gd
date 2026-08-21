class_name SackGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para el Saco de Arpillera Estilizado (Sack).
## Geometría orgánica, low-poly, optimizada y estanca:
## 1. `sack_fabric`: Malla de tela con base aplastada, panza rellena, cuello fruncido y corona/volante superior.
## 2. `sack_rope`: Cuerda de cáñamo atada alrededor del cuello con nudo.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _SackGeometryConfigScript = preload("res://src/geometry_generator/config/sack_geometry_config.gd")

func build_sack_fixture(config = null):
	if config == null:
		config = _SackGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_burlap_sack"

	var s: float = config.scale_mult
	var total_h: float = config.height * s
	var r_base: float = config.base_radius * s
	var r_belly: float = config.belly_radius * s
	var r_neck: float = config.neck_radius * s
	var r_crown: float = config.crown_radius * s
	var n_seg: int = maxi(8, config.segments)

	# Perfil vertical orgánico del saco (8 niveles de anillos)
	var y_levels: Array[float] = [
		0.0,
		total_h * 0.10,
		total_h * 0.32,
		total_h * 0.55,
		total_h * 0.72,
		total_h * 0.77,
		total_h * 0.88,
		total_h
	]

	var r_levels: Array[float] = [
		r_base,
		r_base * 1.15,
		r_belly,
		r_belly * 0.85,
		r_neck * 1.15,
		r_neck,
		r_crown * 0.80,
		r_crown
	]

	# Ángulos base
	var angles: Array[float] = []
	for i in range(n_seg):
		angles.append(float(i) * (TAU / float(n_seg)))

	# ==========================================================================
	# 1. SUPERFICIE DE TELA / ARPILLERA (CUERPO Y VOLANTE SUPERIOR)
	# ==========================================================================
	var g_fabric = _GeneratedMeshScript.new()
	g_fabric.component_id = 0
	var st_fab := SurfaceTool.new()
	st_fab.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. BASE INFERIOR (DISCO PLANO CCW HACIA ABAJO -Y) ---
	var base_center := Vector3(0.0, 0.0, 0.0)
	for i in range(n_seg):
		var i_next: int = (i + 1) % n_seg
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r_base, 0.0, sin(a0) * r_base)
		var p1 := Vector3(cos(a1) * r_base, 0.0, sin(a1) * r_base)
		_add_tri_facing(st_fab, base_center, p1, p0, Vector3(0, -1, 0))

	# --- B. ANILLOS DEL CUERPO DEL SACO ---
	for lv in range(y_levels.size() - 1):
		var y_b: float = y_levels[lv]
		var y_t: float = y_levels[lv + 1]
		var rb: float = r_levels[lv]
		var rt: float = r_levels[lv + 1]

		for i in range(n_seg):
			var i_next: int = (i + 1) % n_seg
			var a0: float = angles[i]
			var a1: float = angles[i_next]

			# Ligera ondulación orgánica en los pliegues superiores
			var r_mod_b: float = rb
			var r_mod_t: float = rt
			if lv >= 5:
				var wave_b: float = sin(float(i) * 3.0) * (0.008 * s)
				var wave_t: float = sin(float(i) * 3.0) * (0.015 * s)
				r_mod_b += wave_b
				r_mod_t += wave_t

			var p_b0 := Vector3(cos(a0) * r_mod_b, y_b, sin(a0) * r_mod_b)
			var p_b1 := Vector3(cos(a1) * r_mod_b, y_b, sin(a1) * r_mod_b)
			var p_t1 := Vector3(cos(a1) * r_mod_t, y_t, sin(a1) * r_mod_t)
			var p_t0 := Vector3(cos(a0) * r_mod_t, y_t, sin(a0) * r_mod_t)

			var n_est := ((p_b0 + p_b1 + p_t0 + p_t1) * 0.25 - Vector3(0, (y_b + y_t) * 0.5, 0)).normalized()
			_add_quad_facing(st_fab, p_b0, p_b1, p_t1, p_t0, n_est)

	# --- C. CIERRE INTERIOR DE LA BOCA SUPERIOR ---
	var crown_top_y: float = total_h
	var inner_knot_y: float = total_h * 0.90
	var knot_center := Vector3(0.0, inner_knot_y, 0.0)

	for i in range(n_seg):
		var i_next: int = (i + 1) % n_seg
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var wave0: float = sin(float(i) * 3.0) * (0.015 * s)
		var wave1: float = sin(float(i_next) * 3.0) * (0.015 * s)

		var p0 := Vector3(cos(a0) * (r_crown + wave0), crown_top_y, sin(a0) * (r_crown + wave0))
		var p1 := Vector3(cos(a1) * (r_crown + wave1), crown_top_y, sin(a1) * (r_crown + wave1))

		_add_tri_facing(st_fab, knot_center, p0, p1, Vector3(0, 1, 0))

	var mesh_fabric := ArrayMesh.new()
	mesh_fabric = st_fab.commit(mesh_fabric)
	mesh_fabric.surface_set_name(0, "SackFabric")
	g_fabric.mesh = mesh_fabric

	# Material Tela / Arpillera Beige Cálida
	var mat_fab := StandardMaterial3D.new()
	mat_fab.albedo_color = config.fabric_color
	mat_fab.roughness = 0.88
	mat_fab.metallic = 0.0
	mat_fab.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_fabric.material_slots[0] = mat_fab
	asset.add_mesh(&"sack_fabric", g_fabric)

	# ==========================================================================
	# 2. SUPERFICIE DE CUERDA (ATADURA DEL CUELLO Y NUDO)
	# ==========================================================================
	var g_rope = _GeneratedMeshScript.new()
	g_rope.component_id = 1
	var st_rope := SurfaceTool.new()
	st_rope.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rope_y: float = total_h * 0.745
	var rope_h: float = 0.035 * s
	var rope_r_in: float = r_neck * 0.95
	var rope_r_out: float = r_neck * 1.35

	# Anillo de la Cuerda
	var y_rb := rope_y - rope_h * 0.5
	var y_rt := rope_y + rope_h * 0.5

	for i in range(n_seg):
		var i_next: int = (i + 1) % n_seg
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_b0 := Vector3(cos(a0) * rope_r_out, y_rb, sin(a0) * rope_r_out)
		var p_b1 := Vector3(cos(a1) * rope_r_out, y_rb, sin(a1) * rope_r_out)
		var p_t1 := Vector3(cos(a1) * rope_r_out, y_rt, sin(a1) * rope_r_out)
		var p_t0 := Vector3(cos(a0) * rope_r_out, y_rt, sin(a0) * rope_r_out)

		var n_r := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5)).normalized()
		_add_quad_facing(st_rope, p_b0, p_b1, p_t1, p_t0, n_r)

		# Borde superior del anillo
		var p_in_t0 := Vector3(cos(a0) * rope_r_in, y_rt, sin(a0) * rope_r_in)
		var p_in_t1 := Vector3(cos(a1) * rope_r_in, y_rt, sin(a1) * rope_r_in)
		_add_quad_facing(st_rope, p_t0, p_t1, p_in_t1, p_in_t0, Vector3(0, 1, 0))

		# Borde inferior del anillo
		var p_in_b0 := Vector3(cos(a0) * rope_r_in, y_rb, sin(a0) * rope_r_in)
		var p_in_b1 := Vector3(cos(a1) * rope_r_in, y_rb, sin(a1) * rope_r_in)
		_add_quad_facing(st_rope, p_in_b0, p_in_b1, p_b1, p_b0, Vector3(0, -1, 0))

	# Nudo frontal / Cabos colgantes
	var knot_pos := Vector3(0.0, rope_y, rope_r_out + 0.010 * s)
	_build_solid_box(st_rope, knot_pos, Vector3(0.045 * s, 0.040 * s, 0.030 * s))
	# Cabo colgante izquierdo
	_build_solid_box(st_rope, knot_pos + Vector3(-0.015 * s, -0.045 * s, 0.005 * s), Vector3(0.016 * s, 0.060 * s, 0.016 * s))
	# Cabo colgante derecho
	_build_solid_box(st_rope, knot_pos + Vector3(0.015 * s, -0.055 * s, 0.005 * s), Vector3(0.016 * s, 0.075 * s, 0.016 * s))

	var mesh_rope := ArrayMesh.new()
	mesh_rope = st_rope.commit(mesh_rope)
	mesh_rope.surface_set_name(0, "SackRope")
	g_rope.mesh = mesh_rope

	# Material Cuerda Marrón Cálido
	var mat_rope := StandardMaterial3D.new()
	mat_rope.albedo_color = config.rope_color
	mat_rope.roughness = 0.85
	mat_rope.metallic = 0.0
	mat_rope.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_rope.material_slots[0] = mat_rope
	asset.add_mesh(&"sack_rope", g_rope)

	# Colisión
	var col_shape := CylinderShape3D.new()
	col_shape.radius = r_belly * 0.95
	col_shape.height = total_h
	g_fabric.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

	return asset

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
