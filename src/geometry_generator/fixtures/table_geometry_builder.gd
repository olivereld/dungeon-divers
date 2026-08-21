class_name TableGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Mesas de Mazmorra / Taberna (Table).
## Geometría estilizada sólida y estanca con normales y devanado CCW garantizados:
## 1. `table_wood`: Tableros de tablones, vigas, patas de caballete y bastidores (marrón cálido homogéneo).
## 2. `table_metal`: Zuncho / aro perimetral y fundas/botas de hierro en las patas (gris oscuro metálico).

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _TableGeometryConfigScript = preload("res://src/geometry_generator/config/table_geometry_config.gd")

func build_table_fixture(config = null):
	if config == null:
		config = _TableGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_tavern_table"

	var s: float = config.scale_mult
	var total_h: float = config.table_height * s
	var p_thick: float = config.plank_thickness * s

	var g_wood = _GeneratedMeshScript.new()
	g_wood.component_id = 0
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_metal = _GeneratedMeshScript.new()
	g_metal.component_id = 1
	var st_metal := SurfaceTool.new()
	st_metal.begin(Mesh.PRIMITIVE_TRIANGLES)

	match config.style:
		_TableGeometryConfigScript.TableStyle.LONG_BANQUET:
			_build_long_banquet_table(st_wood, st_metal, s, total_h, p_thick)
		_TableGeometryConfigScript.TableStyle.ROUND_TAVERN:
			_build_round_tavern_table(st_wood, st_metal, s, total_h, p_thick)
		_TableGeometryConfigScript.TableStyle.STOUT_SQUARE:
			_build_stout_square_table(st_wood, st_metal, s, total_h, p_thick)

	# Commit madera
	var mesh_wood := ArrayMesh.new()
	mesh_wood = st_wood.commit(mesh_wood)
	mesh_wood.surface_set_name(0, "TableWood")
	g_wood.mesh = mesh_wood

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = config.wood_color
	mat_wood.roughness = 0.70
	mat_wood.metallic = 0.0
	mat_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood.material_slots[0] = mat_wood
	asset.add_mesh(&"table_wood", g_wood)

	# Commit metal
	var mesh_metal := ArrayMesh.new()
	mesh_metal = st_metal.commit(mesh_metal)
	if mesh_metal.get_surface_count() > 0:
		mesh_metal.surface_set_name(0, "TableMetal")
		g_metal.mesh = mesh_metal

		var mat_metal := StandardMaterial3D.new()
		mat_metal.albedo_color = config.metal_color
		mat_metal.roughness = 0.38
		mat_metal.metallic = 0.85
		mat_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_metal.material_slots[0] = mat_metal
		asset.add_mesh(&"table_metal", g_metal)

	# Colisión física
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(2.4 * s, total_h, 1.2 * s)
	g_wood.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

	return asset

# ==============================================================================
# 1. MESA LARGA DE BANQUETE / CABALLETE A-FRAME
# ==============================================================================

static func _build_long_banquet_table(
	st_w: SurfaceTool, st_m: SurfaceTool,
	s: float, total_h: float, p_thick: float
) -> void:
	var t_len: float = 2.40 * s
	var t_plank_w: float = 0.27 * s
	var gap: float = 0.018 * s
	var top_cy: float = total_h - p_thick * 0.5

	# 1. Tablero: 3 tablones gruesos longitudinales
	var z_offsets = [-t_plank_w - gap, 0.0, t_plank_w + gap]
	for z_pos in z_offsets:
		_build_solid_box(st_w, Vector3(0.0, top_cy, z_pos), Vector3(t_len, p_thick, t_plank_w))

	# 2. Bastidores / Travesaños bajo el tablero en ambos extremos
	var frame_y: float = total_h - p_thick - 0.045 * s
	var frame_x_span: float = 0.82 * s
	var frame_w: float = 0.74 * s
	var frame_thick: float = 0.09 * s
	var frame_h: float = 0.08 * s

	_build_solid_box(st_w, Vector3(-frame_x_span, frame_y, 0.0), Vector3(frame_thick, frame_h, frame_w))
	_build_solid_box(st_w, Vector3(frame_x_span, frame_y, 0.0), Vector3(frame_thick, frame_h, frame_w))

	# 3. Caballetes / Patas inclinadas A-Frame
	var leg_w: float = 0.10 * s
	var leg_d: float = 0.10 * s
	var leg_top_y: float = frame_y - frame_h * 0.5
	var leg_len: float = leg_top_y / cos(deg_to_rad(14.0))

	for side_x in [-frame_x_span, frame_x_span]:
		# Pata delantera (inclinada hacia +Z)
		var b_front := Basis.from_euler(Vector3(deg_to_rad(-14.0), 0.0, 0.0))
		var pos_front := Vector3(side_x, leg_top_y * 0.5, 0.18 * s)
		_build_oriented_solid_box(st_w, Transform3D(b_front, pos_front), Vector3(leg_w, leg_len, leg_d))

		# Pata trasera (inclinada hacia -Z)
		var b_back := Basis.from_euler(Vector3(deg_to_rad(14.0), 0.0, 0.0))
		var pos_back := Vector3(side_x, leg_top_y * 0.5, -0.18 * s)
		_build_oriented_solid_box(st_w, Transform3D(b_back, pos_back), Vector3(leg_w, leg_len, leg_d))

		# Travesaño inferior entre las dos patas del caballete
		var bar_y: float = 0.16 * s
		_build_solid_box(st_w, Vector3(side_x, bar_y, 0.0), Vector3(leg_w * 1.05, 0.07 * s, 0.56 * s))

		# Pernos / Remaches de hierro forjado sobre el caballete
		_build_solid_box(st_m, Vector3(side_x, bar_y, 0.28 * s), Vector3(0.04 * s, 0.04 * s, 0.015 * s))
		_build_solid_box(st_m, Vector3(side_x, bar_y, -0.28 * s), Vector3(0.04 * s, 0.04 * s, 0.015 * s))

	# 4. Viga longitudinal inferior (Stretcher)
	var long_beam_y: float = 0.16 * s
	_build_solid_box(st_w, Vector3(0.0, long_beam_y, 0.0), Vector3(frame_x_span * 2.0, 0.06 * s, 0.08 * s))

	# 5. Clavos / Pernos de hierro en el tablero sobre las vigas
	for side_x in [-frame_x_span, frame_x_span]:
		for z_pos in z_offsets:
			_build_solid_box(st_m, Vector3(side_x, total_h + 0.003 * s, z_pos), Vector3(0.035 * s, 0.008 * s, 0.035 * s))

# ==============================================================================
# 2. MESA REDONDA DE TABERNA / PIE CENTRAL Y ARO DE HIERRO
# ==============================================================================

static func _build_round_tavern_table(
	st_w: SurfaceTool, st_m: SurfaceTool,
	s: float, total_h: float, p_thick: float
) -> void:
	var radius: float = 0.56 * s
	var segs: int = 16
	var rim_h: float = p_thick * 1.15
	var rim_thick: float = 0.035 * s

	# 1. Tablero circular facetado con tablones de madera
	for i in range(segs):
		var a0: float = float(i) * (TAU / float(segs))
		var a1: float = float(i + 1) * (TAU / float(segs))

		var p_top_c := Vector3(0.0, total_h, 0.0)
		var p_top0 := Vector3(cos(a0) * radius, total_h, sin(a0) * radius)
		var p_top1 := Vector3(cos(a1) * radius, total_h, sin(a1) * radius)

		var p_bot_c := Vector3(0.0, total_h - p_thick, 0.0)
		var p_bot0 := Vector3(cos(a0) * radius, total_h - p_thick, sin(a0) * radius)
		var p_bot1 := Vector3(cos(a1) * radius, total_h - p_thick, sin(a1) * radius)

		# Tapa superior
		_add_tri_facing(st_w, p_top_c, p_top0, p_top1, Vector3(0, 1, 0))
		# Tapa inferior
		_add_tri_facing(st_w, p_bot_c, p_bot1, p_bot0, Vector3(0, -1, 0))

	# Ranuras divisorias de tablones de madera sobre el tablero circular
	var seam_offsets = [-0.22 * s, 0.0, 0.22 * s]
	for z_seam in seam_offsets:
		var seam_len := sqrt(maxf(0.0, radius * radius - z_seam * z_seam)) * 1.94
		_build_solid_box(st_w, Vector3(0.0, total_h + 0.002 * s, z_seam), Vector3(seam_len, 0.005 * s, 0.016 * s))

	# 2. Aro perimetral de hierro forjado (Gris Oscuro Metálico)
	var r_out := radius + rim_thick
	var rim_top := total_h + 0.012 * s
	var rim_bot := total_h - rim_h

	for i in range(segs):
		var a0: float = float(i) * (TAU / float(segs))
		var a1: float = float(i + 1) * (TAU / float(segs))

		var v_tl := Vector3(cos(a0) * r_out, rim_top, sin(a0) * r_out)
		var v_tr := Vector3(cos(a1) * r_out, rim_top, sin(a1) * r_out)
		var v_br := Vector3(cos(a1) * r_out, rim_bot, sin(a1) * r_out)
		var v_bl := Vector3(cos(a0) * r_out, rim_bot, sin(a0) * r_out)

		var n_out := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5)).normalized()
		_add_quad_facing(st_m, v_bl, v_br, v_tr, v_tl, n_out)

		# Bisel superior del aro
		var v_in_l := Vector3(cos(a0) * radius, rim_top, sin(a0) * radius)
		var v_in_r := Vector3(cos(a1) * radius, rim_top, sin(a1) * radius)
		_add_quad_facing(st_m, v_in_l, v_in_r, v_tr, v_tl, Vector3(0, 1, 0))

	# 3. Columna / Fuste Central Cuadrado (Madera)
	var pillar_w: float = 0.13 * s
	var pillar_h: float = total_h - p_thick - 0.06 * s
	var pillar_cy: float = 0.06 * s + pillar_h * 0.5
	_build_solid_box(st_w, Vector3(0.0, pillar_cy, 0.0), Vector3(pillar_w, pillar_h, pillar_w))

	# 4. Peana en cruz de 4 brazos en el suelo
	var base_arm_len: float = 0.58 * s
	var base_arm_w: float = 0.11 * s
	var base_arm_h: float = 0.06 * s
	var base_cy: float = base_arm_h * 0.5
	_build_solid_box(st_w, Vector3(0.0, base_cy, 0.0), Vector3(base_arm_len, base_arm_h, base_arm_w))
	_build_solid_box(st_w, Vector3(0.0, base_cy, 0.0), Vector3(base_arm_w, base_arm_h, base_arm_len))

	# 5. 4 Tirantes diagonales a 45° que apuntalan el pie central
	var strut_thick: float = 0.06 * s
	var strut_len: float = 0.28 * s
	var strut_ang: float = 45.0

	# Tirante +X
	var b_px := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-strut_ang)))
	_build_oriented_solid_box(st_w, Transform3D(b_px, Vector3(0.14 * s, 0.16 * s, 0.0)), Vector3(strut_len, strut_thick, strut_thick))
	# Tirante -X
	var b_nx := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(strut_ang)))
	_build_oriented_solid_box(st_w, Transform3D(b_nx, Vector3(-0.14 * s, 0.16 * s, 0.0)), Vector3(strut_len, strut_thick, strut_thick))
	# Tirante +Z
	var b_pz := Basis.from_euler(Vector3(deg_to_rad(strut_ang), 0.0, 0.0))
	_build_oriented_solid_box(st_w, Transform3D(b_pz, Vector3(0.0, 0.16 * s, 0.14 * s)), Vector3(strut_thick, strut_thick, strut_len))
	# Tirante -Z
	var b_nz := Basis.from_euler(Vector3(deg_to_rad(-strut_ang), 0.0, 0.0))
	_build_oriented_solid_box(st_w, Transform3D(b_nz, Vector3(0.0, 0.16 * s, -0.14 * s)), Vector3(strut_thick, strut_thick, strut_len))

# ==============================================================================
# 3. MESA CUADRADA ROBUSTA CON FUNDAS DE HIERRO
# ==============================================================================

static func _build_stout_square_table(
	st_w: SurfaceTool, st_m: SurfaceTool,
	s: float, total_h: float, p_thick: float
) -> void:
	var t_len: float = 1.60 * s
	var t_plank_w: float = 0.25 * s
	var gap: float = 0.016 * s
	var top_cy: float = total_h - p_thick * 0.5

	# 1. Tablero: 4 tablones gruesos longitudinales
	var z_offsets = [-t_plank_w * 1.5 - gap * 1.5, -t_plank_w * 0.5 - gap * 0.5, t_plank_w * 0.5 + gap * 0.5, t_plank_w * 1.5 + gap * 1.5]
	for z_pos in z_offsets:
		_build_solid_box(st_w, Vector3(0.0, top_cy, z_pos), Vector3(t_len, p_thick, t_plank_w))

	# 2. Bastidor / Marco perimetral inferior
	var apron_y: float = total_h - p_thick - 0.04 * s
	var apron_h: float = 0.08 * s
	var apron_thick: float = 0.06 * s
	var apron_lx: float = 1.28 * s
	var apron_lz: float = 0.78 * s

	# Vigas longitudinales (X)
	_build_solid_box(st_w, Vector3(0.0, apron_y, -apron_lz * 0.5), Vector3(apron_lx, apron_h, apron_thick))
	_build_solid_box(st_w, Vector3(0.0, apron_y, apron_lz * 0.5), Vector3(apron_lx, apron_h, apron_thick))
	# Vigas transversales (Z)
	_build_solid_box(st_w, Vector3(-apron_lx * 0.5, apron_y, 0.0), Vector3(apron_thick, apron_h, apron_lz))
	_build_solid_box(st_w, Vector3(apron_lx * 0.5, apron_y, 0.0), Vector3(apron_thick, apron_h, apron_lz))

	# 3. 4 Patas robustas acampanadas en las esquinas
	var leg_hx: float = apron_lx * 0.5 - 0.02 * s
	var leg_hz: float = apron_lz * 0.5 - 0.02 * s
	var leg_top_y: float = apron_y - apron_h * 0.5
	var leg_h: float = leg_top_y

	var leg_w_bot: float = 0.15 * s

	var leg_pos = [
		Vector3(-leg_hx, leg_h * 0.5, -leg_hz),
		Vector3(leg_hx, leg_h * 0.5, -leg_hz),
		Vector3(-leg_hx, leg_h * 0.5, leg_hz),
		Vector3(leg_hx, leg_h * 0.5, leg_hz)
	]

	for p in leg_pos:
		# Pata de madera
		_build_solid_box(st_w, p, Vector3(leg_w_bot, leg_h, leg_w_bot))

		# 4. Funda / Bota de hierro forjado en la base de cada pata (Metal)
		var boot_h: float = 0.11 * s
		_build_solid_box(st_m, Vector3(p.x, boot_h * 0.5, p.z), Vector3(leg_w_bot + 0.03 * s, boot_h, leg_w_bot + 0.03 * s))

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
