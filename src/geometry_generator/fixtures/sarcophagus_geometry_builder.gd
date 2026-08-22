class_name SarcophagusGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Sarcófagos y Féretros (Sarcophagus).
## Genera sarcófagos estilizados de piedra gótica o madera rústica en 2 partes mecánicas/articulables:
## 1. `sarcophagus_base`: Cajón base hueco con interior, zócalo escalonado, pilastras y arcos de relieve.
## 2. `sarcophagus_lid`: Losa superior tallada con molduras escalonadas y relieves decorativos,
##    con soporte para estados cerrado y abierto (desplazado e inclinado sobre el borde).
## 100% sólido, optimizado y con normales dirigidas CCW.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _SarcophagusGeometryConfigScript = preload("res://src/geometry_generator/config/sarcophagus_geometry_config.gd")

func build_sarcophagus_fixture(config = null) -> _GeneratedAssetScript:
	if config == null:
		config = _SarcophagusGeometryConfigScript.new()

	var base_asset = build_sarcophagus_base(config)
	var lid_asset = build_sarcophagus_lid(config)

	var asset = _GeneratedAssetScript.new()
	var style_prefix: String = "gothic_stone" if config.style == _SarcophagusGeometryConfigScript.Style.GOTHIC_STONE else "rustic_wood"
	var state_suffix: String = "open" if config.is_open else "closed"
	asset.asset_id = StringName("%s_sarcophagus_%s" % [style_prefix, state_suffix])

	# Combinar slots de la base
	for slot_name in base_asset.meshes.keys():
		asset.add_mesh(slot_name, base_asset.get_mesh(slot_name), base_asset.get_mesh_transform(slot_name))

	# Combinar slots de la tapa
	for slot_name in lid_asset.meshes.keys():
		asset.add_mesh(slot_name, lid_asset.get_mesh(slot_name), lid_asset.get_mesh_transform(slot_name))

	return asset

# ==============================================================================
# 1. CONSTRUCTOR DE LA BASE HUECA (SARCOPHAGUS BASE)
# ==============================================================================

func build_sarcophagus_base(config = null) -> _GeneratedAssetScript:
	if config == null:
		config = _SarcophagusGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"sarcophagus_base"

	var s: float = config.scale_mult
	var len_x: float = config.length * s
	var wid_z: float = config.width * s
	var h_base: float = config.base_height * s
	var wt: float = config.wall_thickness * s
	var h_plinth: float = config.plinth_height * s
	var rim_oh: float = config.rim_overhang * s

	var half_len: float = len_x * 0.5
	var half_wid: float = wid_z * 0.5

	# Alturas
	var h_walls: float = h_base - h_plinth
	var walls_center_y: float = h_plinth + h_walls * 0.5

	# --------------------------------------------------------------------------
	# A. CUERPO PRINCIPAL (PAREDES Y FONDO DE LA TINA)
	# --------------------------------------------------------------------------
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Fondo / Suelo interior
	var floor_t: float = wt * 0.9
	_build_solid_box(st_body, Vector3(0.0, h_plinth + floor_t * 0.5, 0.0), Vector3(len_x, floor_t, wid_z))

	# 2. Paredes de la tina (Longitudinales Frontal +Z y Trasera -Z)
	var wall_h: float = h_base - h_plinth - floor_t
	var wall_y: float = h_plinth + floor_t + wall_h * 0.5
	var inner_wid: float = wid_z - wt * 2.0
	var inner_len: float = len_x - wt * 2.0

	_build_solid_box(st_body, Vector3(0.0, wall_y, half_wid - wt * 0.5), Vector3(len_x, wall_h, wt))
	_build_solid_box(st_body, Vector3(0.0, wall_y, -half_wid + wt * 0.5), Vector3(len_x, wall_h, wt))

	# 3. Paredes de la tina (Transversales +X y -X)
	_build_solid_box(st_body, Vector3(half_len - wt * 0.5, wall_y, 0.0), Vector3(wt, wall_h, inner_wid))
	_build_solid_box(st_body, Vector3(-half_len + wt * 0.5, wall_y, 0.0), Vector3(wt, wall_h, inner_wid))

	# 4. Revestimiento / Interior oscuro
	var cloth_h: float = 0.02 * s
	_build_solid_box(st_body, Vector3(0.0, h_plinth + floor_t + cloth_h * 0.5, 0.0), Vector3(inner_len - 0.01 * s, cloth_h, inner_wid - 0.01 * s))

	var mesh_body := ArrayMesh.new()
	mesh_body = st_body.commit(mesh_body)
	mesh_body.surface_set_name(0, "SarcophagusBody")
	g_body.mesh = mesh_body

	var mat_body := StandardMaterial3D.new()
	if config.style == _SarcophagusGeometryConfigScript.Style.GOTHIC_STONE:
		mat_body.albedo_color = config.stone_body_color
		mat_body.roughness = 0.84
	else:
		mat_body.albedo_color = config.wood_body_color
		mat_body.roughness = 0.70
	mat_body.metallic = 0.0
	mat_body.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_body.material_slots[0] = mat_body
	asset.add_mesh(&"sarcophagus_base_body", g_body)

	# --------------------------------------------------------------------------
	# B. MOLDURAS, ZÓCALO, PILASTRAS Y ARCOS DECORATIVOS (TRIM)
	# --------------------------------------------------------------------------
	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Zócalo base inferior escalonado (Plinth)
	var plinth_w: float = len_x + rim_oh * 2.0
	var plinth_d: float = wid_z + rim_oh * 2.0
	_build_solid_box(st_trim, Vector3(0.0, h_plinth * 0.5, 0.0), Vector3(plinth_w, h_plinth, plinth_d))

	# 2. Reborde superior moldurado (Rim)
	var rim_h: float = 0.045 * s
	var rim_w: float = len_x + rim_oh * 1.5
	var rim_d: float = wid_z + rim_oh * 1.5
	var rim_y: float = h_base - rim_h * 0.5

	# Molduras perimetrales exteriores superiores
	_build_solid_box(st_trim, Vector3(0.0, rim_y, half_wid + rim_oh * 0.5), Vector3(rim_w, rim_h, rim_oh * 1.5))
	_build_solid_box(st_trim, Vector3(0.0, rim_y, -half_wid - rim_oh * 0.5), Vector3(rim_w, rim_h, rim_oh * 1.5))
	_build_solid_box(st_trim, Vector3(half_len + rim_oh * 0.5, rim_y, 0.0), Vector3(rim_oh * 1.5, rim_h, wid_z))
	_build_solid_box(st_trim, Vector3(-half_len - rim_oh * 0.5, rim_y, 0.0), Vector3(rim_oh * 1.5, rim_h, wid_z))

	# 3. 4 Pilastras de esquina exteriores
	var pw: float = wt * 1.35
	var pil_cx: float = half_len + rim_oh * 0.25 - pw * 0.5
	var pil_cz: float = half_wid + rim_oh * 0.25 - pw * 0.5

	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var p_pos := Vector3(float(ix) * pil_cx, walls_center_y, float(iz) * pil_cz)
			_build_solid_box(st_trim, p_pos, Vector3(pw, h_walls, pw))

	# 4. Relieves decorativos góticos / arquerías ciegas en laterales largos
	var num_arches: int = 4
	var arch_w: float = (len_x - pw * 2.2) / float(num_arches)
	var arch_h: float = h_walls * 0.70
	var arch_t: float = 0.015 * s
	var arch_y: float = h_plinth + h_walls * 0.45

	for i in range(num_arches):
		var arch_cx: float = -half_len + pw * 1.2 + arch_w * (float(i) + 0.5)
		# Relieve frontal (+Z)
		_build_solid_box(st_trim, Vector3(arch_cx, arch_y, half_wid + arch_t * 0.5), Vector3(arch_w * 0.78, arch_h, arch_t))
		# Relieve trasero (-Z)
		_build_solid_box(st_trim, Vector3(arch_cx, arch_y, -half_wid - arch_t * 0.5), Vector3(arch_w * 0.78, arch_h, arch_t))

	# En los extremos cortos (+X y -X), relieve central
	var end_relief_w: float = wid_z * 0.55
	_build_solid_box(st_trim, Vector3(half_len + arch_t * 0.5, arch_y, 0.0), Vector3(arch_t, arch_h, end_relief_w))
	_build_solid_box(st_trim, Vector3(-half_len - arch_t * 0.5, arch_y, 0.0), Vector3(arch_t, arch_h, end_relief_w))

	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	mesh_trim.surface_set_name(0, "SarcophagusTrim")
	g_trim.mesh = mesh_trim

	var mat_trim := StandardMaterial3D.new()
	if config.style == _SarcophagusGeometryConfigScript.Style.GOTHIC_STONE:
		mat_trim.albedo_color = config.stone_trim_color
		mat_trim.roughness = 0.76
		mat_trim.metallic = 0.0
	else:
		mat_trim.albedo_color = config.wood_trim_color
		mat_trim.roughness = 0.65
		mat_trim.metallic = 0.0
	mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_trim.material_slots[0] = mat_trim
	asset.add_mesh(&"sarcophagus_base_trim", g_trim)

	# Colisión de la base
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(plinth_w, h_base, plinth_d)
	g_body.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, h_base * 0.5, 0.0)))

	return asset

# ==============================================================================
# 2. CONSTRUCTOR DE LA TAPA PESADA (SARCOPHAGUS LID)
# ==============================================================================

func build_sarcophagus_lid(config = null) -> _GeneratedAssetScript:
	if config == null:
		config = _SarcophagusGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"sarcophagus_lid"

	var s: float = config.scale_mult
	var len_x: float = config.length * s
	var wid_z: float = config.width * s
	var h_base: float = config.base_height * s
	var t_lid: float = config.lid_thickness * s
	var rim_oh: float = config.rim_overhang * s

	var lid_w: float = len_x + rim_oh * 2.4
	var lid_d: float = wid_z + rim_oh * 2.4

	# --------------------------------------------------------------------------
	# A. CUERPO DE LA LOSA / TAPA
	# --------------------------------------------------------------------------
	var g_lid_body = _GeneratedMeshScript.new()
	g_lid_body.component_id = 0
	var st_lb := SurfaceTool.new()
	st_lb.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Losa base principal
	var slab_h: float = t_lid * 0.55
	_build_solid_box(st_lb, Vector3(0.0, slab_h * 0.5, 0.0), Vector3(lid_w, slab_h, lid_d))

	# Losa escalonada superior
	var step_w: float = lid_w - 0.07 * s
	var step_d: float = lid_d - 0.07 * s
	var step_h: float = t_lid * 0.45
	_build_solid_box(st_lb, Vector3(0.0, slab_h + step_h * 0.5, 0.0), Vector3(step_w, step_h, step_d))

	var mesh_lb := ArrayMesh.new()
	mesh_lb = st_lb.commit(mesh_lb)
	mesh_lb.surface_set_name(0, "SarcophagusLidBody")
	g_lid_body.mesh = mesh_lb

	var mat_lb := StandardMaterial3D.new()
	if config.style == _SarcophagusGeometryConfigScript.Style.GOTHIC_STONE:
		mat_lb.albedo_color = config.stone_body_color
		mat_lb.roughness = 0.82
	else:
		mat_lb.albedo_color = config.wood_body_color
		mat_lb.roughness = 0.68
	mat_lb.metallic = 0.0
	mat_lb.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_lid_body.material_slots[0] = mat_lb

	# --------------------------------------------------------------------------
	# B. RELIEVES, RUNAS Y MOLDURAS DE LA TAPA
	# --------------------------------------------------------------------------
	var g_lid_trim = _GeneratedMeshScript.new()
	g_lid_trim.component_id = 1
	var st_lt := SurfaceTool.new()
	st_lt.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Banda de relieve central longitudinal (Cruz / Runa / Motivo funerario)
	var band_w: float = step_w - 0.12 * s
	var band_d: float = 0.14 * s
	var band_h: float = 0.025 * s
	var band_y: float = t_lid + band_h * 0.5
	_build_solid_box(st_lt, Vector3(0.0, band_y, 0.0), Vector3(band_w, band_h, band_d))

	# Brazos transversales de la cruz o refuerzos de banda
	var cross_w: float = 0.16 * s
	var cross_d: float = step_d - 0.10 * s
	_build_solid_box(st_lt, Vector3(0.0, band_y, 0.0), Vector3(cross_w, band_h, cross_d))

	# Moldura de marco exterior de la tapa
	var rim_frame_t: float = 0.020 * s
	_build_solid_box(st_lt, Vector3(0.0, t_lid + rim_frame_t * 0.5, step_d * 0.5 - 0.025 * s), Vector3(step_w, rim_frame_t, 0.05 * s))
	_build_solid_box(st_lt, Vector3(0.0, t_lid + rim_frame_t * 0.5, -step_d * 0.5 + 0.025 * s), Vector3(step_w, rim_frame_t, 0.05 * s))
	_build_solid_box(st_lt, Vector3(step_w * 0.5 - 0.025 * s, t_lid + rim_frame_t * 0.5, 0.0), Vector3(0.05 * s, rim_frame_t, step_d))
	_build_solid_box(st_lt, Vector3(-step_w * 0.5 + 0.025 * s, t_lid + rim_frame_t * 0.5, 0.0), Vector3(0.05 * s, rim_frame_t, step_d))

	var mesh_lt := ArrayMesh.new()
	mesh_lt = st_lt.commit(mesh_lt)
	mesh_lt.surface_set_name(0, "SarcophagusLidTrim")
	g_lid_trim.mesh = mesh_lt

	var mat_lt := StandardMaterial3D.new()
	if config.style == _SarcophagusGeometryConfigScript.Style.GOTHIC_STONE:
		mat_lt.albedo_color = config.stone_trim_color
		mat_lt.roughness = 0.72
		mat_lt.metallic = 0.0
	else:
		mat_lt.albedo_color = config.wood_trim_color
		mat_lt.roughness = 0.60
		mat_lt.metallic = 0.0
	mat_lt.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_lid_trim.material_slots[0] = mat_lt

	# --------------------------------------------------------------------------
	# C. TRANSFORMACIÓN SEGÚN ESTADO (ABIERTO / CERRADO)
	# --------------------------------------------------------------------------
	var lid_transform: Transform3D

	if config.is_open:
		# Tapa desplazada e inclinada sobre el borde
		var slide_x: float = config.open_slide_x * s
		var slide_z: float = config.open_slide_z * s
		var tilt_rad: float = deg_to_rad(config.open_tilt_deg)
		var rot_y_rad: float = deg_to_rad(config.open_rot_y_deg)

		var basis := Basis()
		basis = basis.rotated(Vector3.UP, rot_y_rad)
		basis = basis.rotated(Vector3.FORWARD, tilt_rad)

		var lid_pos := Vector3(slide_x, h_base + 0.02 * s, slide_z)
		lid_transform = Transform3D(basis, lid_pos)
	else:
		# Tapa cerrada y alineada perfectamente sobre el reborde
		lid_transform = Transform3D(Basis(), Vector3(0.0, h_base, 0.0))

	# Aplicar transformación de montaje a la tapa
	_apply_transform_to_mesh(g_lid_body, lid_transform)
	_apply_transform_to_mesh(g_lid_trim, lid_transform)

	asset.add_mesh(&"sarcophagus_lid_body", g_lid_body)
	asset.add_mesh(&"sarcophagus_lid_trim", g_lid_trim)

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

static func _apply_transform_to_mesh(gen_mesh: _GeneratedMeshScript, xform: Transform3D) -> void:
	if gen_mesh == null or gen_mesh.mesh == null:
		return

	var orig_mesh = gen_mesh.mesh
	var surface_count = orig_mesh.get_surface_count()
	var new_mesh = ArrayMesh.new()

	for s in range(surface_count):
		var arrays = orig_mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices = arrays[Mesh.ARRAY_INDEX]

		var new_st := SurfaceTool.new()
		new_st.begin(Mesh.PRIMITIVE_TRIANGLES)

		if indices == null or indices.is_empty():
			for i in range(vertices.size()):
				new_st.set_normal(xform.basis * normals[i])
				if uvs != null and not uvs.is_empty():
					new_st.set_uv(uvs[i])
				new_st.add_vertex(xform * vertices[i])
		else:
			for idx in indices:
				new_st.set_normal(xform.basis * normals[idx])
				if uvs != null and not uvs.is_empty():
					new_st.set_uv(uvs[idx])
				new_st.add_vertex(xform * vertices[idx])

		new_mesh = new_st.commit(new_mesh)
		new_mesh.surface_set_name(s, orig_mesh.surface_get_name(s))

	gen_mesh.mesh = new_mesh
