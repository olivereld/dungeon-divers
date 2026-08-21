class_name RubbleGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Derrumbes y Escombros (Rubble).
## Genera montículos de colapso de muros y techos con bloques de piedra,
## ladrillos contrastados, sustrato de grava y guijarros dispersos.
## Geometría 100% estanca con normales y devanado CCW garantizados.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _RubbleGeometryConfigScript = preload("res://src/geometry_generator/config/rubble_geometry_config.gd")

func build_rubble_fixture(config = null):
	if config == null:
		config = _RubbleGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_rubble_collapse"

	var s: float = config.scale_mult
	var m_rad: float = config.mound_radius * s
	var m_h: float = config.mound_height * s
	var n_blocks: int = config.block_count
	var n_pebbles: int = config.pebble_count

	# Generador pseudo-aleatorio determinista
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	# ==========================================================================
	# 1. SUSTRATO BASE DE GRAVA Y POLVO DE ESCOMBROS (MOUND SUBSTRATE)
	# ==========================================================================
	var g_gravel = _GeneratedMeshScript.new()
	g_gravel.component_id = 0
	var st_gravel := SurfaceTool.new()
	st_gravel.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mound_segments: int = 12
	var mound_pts: Array[Vector3] = []
	for i in range(mound_segments):
		var ang: float = float(i) * (TAU / float(mound_segments))
		var r_noise: float = m_rad * rng.randf_range(0.82, 1.18)
		var px: float = cos(ang) * r_noise
		var pz: float = sin(ang) * r_noise
		var py: float = rng.randf_range(0.015 * s, 0.040 * s)
		mound_pts.append(Vector3(px, py, pz))

	# Vértice central elevado del montículo
	var peak_pt := Vector3(
		rng.randf_range(-0.10 * s, 0.10 * s),
		m_h * rng.randf_range(0.85, 1.10),
		rng.randf_range(-0.10 * s, 0.10 * s)
	)

	# Caras superiores del montículo (CCW hacia arriba)
	for i in range(mound_segments):
		var i_next: int = (i + 1) % mound_segments
		var p0 := mound_pts[i]
		var p1 := mound_pts[i_next]
		var n := (p0 - peak_pt).cross(p1 - peak_pt).normalized()
		_add_tri_facing(st_gravel, peak_pt, p0, p1, n)

	# Faldón/Base inferior hacia el suelo
	var floor_center := Vector3(0.0, 0.0, 0.0)
	for i in range(mound_segments):
		var i_next: int = (i + 1) % mound_segments
		var p0 := mound_pts[i]
		var p1 := mound_pts[i_next]
		_add_tri_facing(st_gravel, floor_center, p1, p0, Vector3(0, -1, 0))

	var mesh_gravel := ArrayMesh.new()
	mesh_gravel = st_gravel.commit(mesh_gravel)
	mesh_gravel.surface_set_name(0, "RubbleGravel")
	g_gravel.mesh = mesh_gravel

	var mat_gravel := StandardMaterial3D.new()
	mat_gravel.albedo_color = config.gravel_color
	mat_gravel.roughness = 0.90
	mat_gravel.metallic = 0.0
	mat_gravel.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_gravel.material_slots[0] = mat_gravel
	asset.add_mesh(&"rubble_gravel", g_gravel)

	# ==========================================================================
	# 2. BLOQUES Y SILLARES DE PIEDRA PRINCIPAL (DUNGEON STONE MASONRY)
	# ==========================================================================
	var g_stone_pri = _GeneratedMeshScript.new()
	g_stone_pri.component_id = 1
	var st_pri := SurfaceTool.new()
	st_pri.begin(Mesh.PRIMITIVE_TRIANGLES)

	# ==========================================================================
	# 3. LADRILLOS CONTRASTADOS DE TERRACOTA / PIZARRA (SECONDARY ACCENTS)
	# ==========================================================================
	var g_stone_sec = _GeneratedMeshScript.new()
	g_stone_sec.component_id = 2
	var st_sec := SurfaceTool.new()
	st_sec.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Distribuir bloques estructurales
	for i in range(n_blocks):
		# Distancia radial normalizada (más densidad cerca del centro)
		var t_r := sqrt(rng.randf())
		var dist: float = t_r * (m_rad * 0.85)
		var ang: float = rng.randf_range(0.0, TAU)

		var pos_x: float = cos(ang) * dist
		var pos_z: float = sin(ang) * dist
		# Altura según el perfil del montículo
		var h_factor := 1.0 - clampf(dist / m_rad, 0.0, 1.0)
		var pos_y: float = (m_h * h_factor * 0.75) + rng.randf_range(0.04 * s, 0.12 * s)

		# Dimensiones del bloque
		var is_large: bool = (i < 4) or (rng.randf() < 0.25)
		var b_sz: Vector3
		if is_large:
			b_sz = Vector3(
				rng.randf_range(0.28 * s, 0.44 * s),
				rng.randf_range(0.14 * s, 0.22 * s),
				rng.randf_range(0.22 * s, 0.36 * s)
			)
		else:
			b_sz = Vector3(
				rng.randf_range(0.16 * s, 0.28 * s),
				rng.randf_range(0.08 * s, 0.14 * s),
				rng.randf_range(0.12 * s, 0.22 * s)
			)

		# Rotación orgánica en 3 ejes (inclinado como caído naturalmente)
		var rot_x: float = deg_to_rad(rng.randf_range(-26.0, 26.0))
		var rot_y: float = deg_to_rad(rng.randf_range(-180.0, 180.0))
		var rot_z: float = deg_to_rad(rng.randf_range(-22.0, 22.0))

		var basis := Basis.from_euler(Vector3(rot_x, rot_y, rot_z))
		var xform := Transform3D(basis, Vector3(pos_x, pos_y, pos_z))

		# 75% piedra gris principal, 25% ladrillo terracota contrastado
		var target_st: SurfaceTool = st_sec if (rng.randf() < 0.28) else st_pri
		_build_oriented_solid_box(target_st, xform, b_sz)

	var mesh_pri := ArrayMesh.new()
	mesh_pri = st_pri.commit(mesh_pri)
	mesh_pri.surface_set_name(0, "RubbleStonePrimary")
	g_stone_pri.mesh = mesh_pri

	var mat_pri := StandardMaterial3D.new()
	mat_pri.albedo_color = config.primary_stone_color
	mat_pri.roughness = 0.78
	mat_pri.metallic = 0.0
	mat_pri.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_stone_pri.material_slots[0] = mat_pri
	asset.add_mesh(&"rubble_stone_primary", g_stone_pri)

	var mesh_sec := ArrayMesh.new()
	mesh_sec = st_sec.commit(mesh_sec)
	mesh_sec.surface_set_name(0, "RubbleStoneSecondary")
	g_stone_sec.mesh = mesh_sec

	var mat_sec := StandardMaterial3D.new()
	mat_sec.albedo_color = config.secondary_stone_color
	mat_sec.roughness = 0.82
	mat_sec.metallic = 0.0
	mat_sec.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_stone_sec.material_slots[0] = mat_sec
	asset.add_mesh(&"rubble_stone_secondary", g_stone_sec)

	# ==========================================================================
	# 4. GUIJARROS Y ESQUIRLAS PEQUEÑAS DE ROCA (DEBRIS PEBBLES)
	# ==========================================================================
	var g_pebbles = _GeneratedMeshScript.new()
	g_pebbles.component_id = 3
	var st_peb := SurfaceTool.new()
	st_peb.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(n_pebbles):
		var dist_p := rng.randf_range(0.20 * m_rad, m_rad * 1.15)
		var ang_p := rng.randf_range(0.0, TAU)
		var p_pos := Vector3(
			cos(ang_p) * dist_p,
			rng.randf_range(0.02 * s, 0.08 * s),
			sin(ang_p) * dist_p
		)
		var p_sz := Vector3(
			rng.randf_range(0.04 * s, 0.09 * s),
			rng.randf_range(0.03 * s, 0.06 * s),
			rng.randf_range(0.04 * s, 0.08 * s)
		)

		var p_basis := Basis.from_euler(Vector3(
			deg_to_rad(rng.randf_range(-45.0, 45.0)),
			deg_to_rad(rng.randf_range(-180.0, 180.0)),
			deg_to_rad(rng.randf_range(-45.0, 45.0))
		))
		var p_xform := Transform3D(p_basis, p_pos)
		_build_oriented_solid_box(st_peb, p_xform, p_sz)

	var mesh_peb := ArrayMesh.new()
	mesh_peb = st_peb.commit(mesh_peb)
	mesh_peb.surface_set_name(0, "RubblePebbles")
	g_pebbles.mesh = mesh_peb

	var mat_peb := StandardMaterial3D.new()
	mat_peb.albedo_color = config.gravel_color.lerp(config.primary_stone_color, 0.5)
	mat_peb.roughness = 0.85
	mat_peb.metallic = 0.0
	mat_peb.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_pebbles.material_slots[0] = mat_peb
	asset.add_mesh(&"rubble_pebbles", g_pebbles)

	# Colisión
	var col_shape := CylinderShape3D.new()
	col_shape.radius = m_rad * 0.90
	col_shape.height = m_h * 1.20
	g_stone_pri.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, m_h * 0.60, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS ORIENTADOS CON NORMALES DIRIGIDAS
# ==============================================================================

static func _build_oriented_solid_box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	# 8 vertices locales transformados
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

	# 1. Frontal (+Z)
	_add_quad_facing(st, v_bl_f, v_br_f, v_tr_f, v_tl_f, n_front)
	# 2. Trasera (-Z)
	_add_quad_facing(st, v_br_b, v_bl_b, v_tl_b, v_tr_b, n_back)
	# 3. Derecha (+X)
	_add_quad_facing(st, v_br_f, v_br_b, v_tr_b, v_tr_f, n_right)
	# 4. Izquierda (-X)
	_add_quad_facing(st, v_bl_b, v_bl_f, v_tl_f, v_tl_b, n_left)
	# 5. Superior (+Y)
	_add_quad_facing(st, v_tl_f, v_tr_f, v_tr_b, v_tl_b, n_top)
	# 6. Inferior (-Y)
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
