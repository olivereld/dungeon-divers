class_name TombstoneGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Lápidas de Piedra (Tombstone).
## Geometría 100% estanca con normales y devanado CCW garantizados:
## 1. `tombstone_stone`: Cuerpo principal de piedra de la lápida y pedestal.
## 2. `tombstone_trim`: Relieves de cruz, marco perimetral y aureola celta.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _TombstoneGeometryConfigScript = preload("res://src/geometry_generator/config/tombstone_geometry_config.gd")

func build_tombstone_fixture(config = null):
	if config == null:
		config = _TombstoneGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_stone_tombstone"

	var s: float = config.scale_mult
	var w: float = config.width * s
	var d: float = config.depth * s
	var total_h: float = config.height * s
	var bw: float = config.base_width * s
	var bd: float = config.base_depth * s
	var bh: float = config.base_height * s

	var g_stone = _GeneratedMeshScript.new()
	g_stone.component_id = 0
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	match config.style:
		_TombstoneGeometryConfigScript.TombstoneStyle.CLASSIC_ARCH:
			_build_classic_arch(st_stone, st_trim, s, w, d, total_h, bw, bd, bh)
		_TombstoneGeometryConfigScript.TombstoneStyle.CELTIC_CROSS:
			_build_celtic_cross(st_stone, st_trim, s, w, d, total_h, bw, bd, bh)
		_TombstoneGeometryConfigScript.TombstoneStyle.BROKEN_SLAB:
			_build_broken_slab(st_stone, st_trim, s, w, d, total_h, bw, bd, bh)

	# Commit superficies
	var mesh_stone := ArrayMesh.new()
	mesh_stone = st_stone.commit(mesh_stone)
	mesh_stone.surface_set_name(0, "TombstoneStone")
	g_stone.mesh = mesh_stone

	var mat_stone := StandardMaterial3D.new()
	mat_stone.albedo_color = config.stone_color
	mat_stone.roughness = 0.84
	mat_stone.metallic = 0.0
	mat_stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_stone.material_slots[0] = mat_stone
	asset.add_mesh(&"tombstone_stone", g_stone)

	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	mesh_trim.surface_set_name(0, "TombstoneTrim")
	g_trim.mesh = mesh_trim

	var mat_trim := StandardMaterial3D.new()
	mat_trim.albedo_color = config.stone_trim_color
	mat_trim.roughness = 0.76
	mat_trim.metallic = 0.0
	mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_trim.material_slots[0] = mat_trim
	asset.add_mesh(&"tombstone_trim", g_trim)

	# Colisión física
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(bw, total_h, bd)
	g_stone.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

	return asset

# ==============================================================================
# ESTILOS DE LÁPIDAS
# ==============================================================================

static func _build_classic_arch(
	st_s: SurfaceTool, st_t: SurfaceTool,
	s: float, w: float, d: float, total_h: float,
	bw: float, bd: float, bh: float
) -> void:
	# 1. Zócalo base
	_build_solid_box(st_s, Vector3(0.0, bh * 0.5, 0.0), Vector3(bw, bh, bd))
	# Moldura de bisel sobre la base
	_build_solid_box(st_s, Vector3(0.0, bh + 0.015 * s, 0.0), Vector3(bw - 0.04 * s, 0.03 * s, bd - 0.04 * s))

	# 2. Cuerpo rectangular inferior
	var arch_r: float = w * 0.5
	var rect_h: float = total_h - bh - arch_r - 0.03 * s
	var rect_cy: float = bh + 0.03 * s + rect_h * 0.5
	_build_solid_box(st_s, Vector3(0.0, rect_cy, 0.0), Vector3(w, rect_h, d))

	# 3. Arco superior semicircular
	var arch_center := Vector3(0.0, bh + 0.03 * s + rect_h, 0.0)
	var segs := 10
	var hd := d * 0.5

	for i in range(segs):
		var a0: float = float(i) * (PI / float(segs))
		var a1: float = float(i + 1) * (PI / float(segs))

		# Invertir para recorrer de izquierda a derecha sobre el arco (+X a -X)
		var p_f0 := arch_center + Vector3(cos(a0) * arch_r, sin(a0) * arch_r, hd)
		var p_f1 := arch_center + Vector3(cos(a1) * arch_r, sin(a1) * arch_r, hd)
		var p_b0 := arch_center + Vector3(cos(a0) * arch_r, sin(a0) * arch_r, -hd)
		var p_b1 := arch_center + Vector3(cos(a1) * arch_r, sin(a1) * arch_r, -hd)

		# Cara frontal (+Z)
		_add_tri_facing(st_s, arch_center + Vector3(0, 0, hd), p_f0, p_f1, Vector3(0, 0, 1))
		# Cara trasera (-Z)
		_add_tri_facing(st_s, arch_center + Vector3(0, 0, -hd), p_b1, p_b0, Vector3(0, 0, -1))
		# Tejadillo / Bóveda exterior
		var n_arch := Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0.0).normalized()
		_add_quad_facing(st_s, p_f0, p_b0, p_b1, p_f1, n_arch)

	# 4. Marco perimetral y Cruz grabada en relieve (Trim)
	var cross_y := rect_cy + 0.08 * s
	var cross_z := hd + 0.008 * s
	# Palo vertical de la cruz
	_build_solid_box(st_t, Vector3(0.0, cross_y, cross_z), Vector3(0.045 * s, 0.22 * s, 0.016 * s))
	# Travesaño horizontal
	_build_solid_box(st_t, Vector3(0.0, cross_y + 0.035 * s, cross_z), Vector3(0.14 * s, 0.045 * s, 0.016 * s))

	# Pequeña moldura de marco en la base de la estela
	_build_solid_box(st_t, Vector3(0.0, bh + 0.045 * s, hd + 0.005 * s), Vector3(w * 0.90, 0.025 * s, 0.012 * s))

static func _build_celtic_cross(
	st_s: SurfaceTool, st_t: SurfaceTool,
	s: float, w: float, d: float, total_h: float,
	bw: float, bd: float, bh: float
) -> void:
	# 1. Pedestal escalonado
	_build_solid_box(st_s, Vector3(0.0, bh * 0.5, 0.0), Vector3(bw * 1.15, bh, bd * 1.15))
	_build_solid_box(st_s, Vector3(0.0, bh * 1.25, 0.0), Vector3(bw * 0.85, bh * 0.75, bd * 0.85))

	# 2. Vástago vertical de la cruz
	var stem_h: float = total_h - bh * 1.65
	var stem_w: float = 0.14 * s
	var stem_d: float = d * 0.90
	var stem_cy: float = bh * 1.65 + stem_h * 0.5
	_build_solid_box(st_s, Vector3(0.0, stem_cy, 0.0), Vector3(stem_w, stem_h, stem_d))

	# 3. Travesaño horizontal
	var crossbar_y: float = total_h - 0.24 * s
	var crossbar_w: float = 0.44 * s
	var crossbar_h: float = 0.12 * s
	_build_solid_box(st_s, Vector3(0.0, crossbar_y, 0.0), Vector3(crossbar_w, crossbar_h, stem_d))

	# 4. Aureola / Anillo celta circular
	var ring_center := Vector3(0.0, crossbar_y, 0.0)
	var r_in := 0.12 * s
	var r_out := 0.18 * s
	var r_thick := stem_d * 0.65
	var segs := 12

	for i in range(segs):
		var a0: float = float(i) * (TAU / float(segs))
		var a1: float = float(i + 1) * (TAU / float(segs))

		var p_f_in0 := ring_center + Vector3(cos(a0) * r_in, sin(a0) * r_in, r_thick * 0.5)
		var p_f_in1 := ring_center + Vector3(cos(a1) * r_in, sin(a1) * r_in, r_thick * 0.5)
		var p_f_out0 := ring_center + Vector3(cos(a0) * r_out, sin(a0) * r_out, r_thick * 0.5)
		var p_f_out1 := ring_center + Vector3(cos(a1) * r_out, sin(a1) * r_out, r_thick * 0.5)

		var p_b_in0 := ring_center + Vector3(cos(a0) * r_in, sin(a0) * r_in, -r_thick * 0.5)
		var p_b_in1 := ring_center + Vector3(cos(a1) * r_in, sin(a1) * r_in, -r_thick * 0.5)
		var p_b_out0 := ring_center + Vector3(cos(a0) * r_out, sin(a0) * r_out, -r_thick * 0.5)
		var p_b_out1 := ring_center + Vector3(cos(a1) * r_out, sin(a1) * r_out, -r_thick * 0.5)

		# Frontal
		_add_quad_facing(st_t, p_f_in0, p_f_out0, p_f_out1, p_f_in1, Vector3(0, 0, 1))
		# Trasera
		_add_quad_facing(st_t, p_b_in1, p_b_out1, p_b_out0, p_b_in0, Vector3(0, 0, -1))
		# Borde exterior
		var n_out := Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0.0).normalized()
		_add_quad_facing(st_t, p_f_out0, p_b_out0, p_b_out1, p_f_out1, n_out)

	# Medallón central en la intersección
	_build_solid_box(st_t, Vector3(0.0, crossbar_y, stem_d * 0.5 + 0.010 * s), Vector3(0.08 * s, 0.08 * s, 0.020 * s))

static func _build_broken_slab(
	st_s: SurfaceTool, st_t: SurfaceTool,
	s: float, w: float, d: float, total_h: float,
	bw: float, bd: float, bh: float
) -> void:
	# 1. Zócalo base
	_build_solid_box(st_s, Vector3(0.0, bh * 0.5, 0.0), Vector3(bw, bh, bd))

	# 2. Tocón quebrado inferior
	var stump_h: float = total_h * 0.32
	var stump_cy: float = bh + stump_h * 0.5
	_build_solid_box(st_s, Vector3(-0.04 * s, stump_cy, 0.0), Vector3(w * 0.92, stump_h, d))

	# Fractura diagonal del tocón
	_build_solid_box(st_s, Vector3(0.08 * s, bh + stump_h - 0.02 * s, 0.0), Vector3(0.18 * s, 0.06 * s, d * 0.95))

	# 3. Losa superior caída en el suelo
	var fallen_w: float = w * 0.95
	var fallen_h: float = total_h * 0.50
	var fallen_center := Vector3(0.18 * s, 0.12 * s, 0.12 * s)

	var basis := Basis.from_euler(Vector3(deg_to_rad(68.0), deg_to_rad(25.0), deg_to_rad(-18.0)))
	var xform := Transform3D(basis, fallen_center)
	_build_oriented_solid_box(st_s, xform, Vector3(fallen_w, fallen_h, d))

	# Esquirlas de piedra caídas en la fractura
	_build_solid_box(st_t, Vector3(-0.12 * s, 0.03 * s, 0.20 * s), Vector3(0.06 * s, 0.04 * s, 0.05 * s))
	_build_solid_box(st_t, Vector3(0.24 * s, 0.03 * s, -0.15 * s), Vector3(0.05 * s, 0.03 * s, 0.06 * s))

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
