class_name UrnGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Urnas Funerarias, Vasijas de Mazmorra y Frascos Canopos (Urns).
## Implementa 4 estilos procedurales inspirados en criptas y templos góticos:
## 1. BANDED_STONE_URN: Vasija ovoidal con boca ancha acampanada y bandas horizontales en relieve.
## 2. SKULL_RELIC_URN: Urna funeraria con tapa cilíndrica biselada, hombro angulado y relieve gótico frontal.
## 3. CEREMONIAL_PEDESTAL: Copa/urna monumental sobre pedestal cuadrado con fuste torneado, cáliz moldurado y tapa con pomo en aguja.
## 4. CANOPIC_JAR: Frasco canopo compacto para mesas y altares con cuello alto y proporciones refinadas.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _UrnGeometryConfigScript = preload("res://src/geometry_generator/config/urn_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_urn_fixture(config = null):
	if config == null:
		config = _UrnGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	var s: float = config.scale_mult
	var num_sides: int = maxi(6, config.num_sides)
	var angles: Array[float] = []
	for i in range(num_sides):
		angles.append(float(i) * (TAU / float(num_sides)))

	match config.style:
		_UrnGeometryConfigScript.Style.BANDED_STONE_URN:
			asset.asset_id = &"banded_stone_urn"
			_build_banded_urn(asset, config, angles, s)
		_UrnGeometryConfigScript.Style.SKULL_RELIC_URN:
			asset.asset_id = &"skull_relic_urn"
			_build_skull_relic_urn(asset, config, angles, s)
		_UrnGeometryConfigScript.Style.CEREMONIAL_PEDESTAL:
			asset.asset_id = &"ceremonial_pedestal_urn"
			_build_ceremonial_pedestal_urn(asset, config, angles, s)
		_UrnGeometryConfigScript.Style.CANOPIC_JAR:
			asset.asset_id = &"canopic_jar_surface"
			_build_canopic_jar(asset, config, angles, s)
		_:
			asset.asset_id = &"banded_stone_urn"
			_build_banded_urn(asset, config, angles, s)

	return asset

# ==============================================================================
# ESTILO 1: URNA OVOIDAL CON BANDAS EN RELIEVE (BANDED STONE/CLAY URN)
# ==============================================================================

func _build_banded_urn(asset: _GeneratedAssetScript, config: _UrnGeometryConfigScript, angles: Array[float], s: float) -> void:
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Base y pie circular
	var y_base: float = 0.0
	var y_foot: float = 0.06 * s
	var r_base: float = 0.16 * s
	var r_foot: float = 0.19 * s
	_build_ngon_cap(st_body, y_base, r_base, angles, false)
	_build_ngon_frustum(st_body, y_base, y_foot, r_base, r_foot, angles)

	# 2. Cuerpo abombado principal por estratos
	var y_belly_low: float = 0.22 * s
	var y_belly_mid: float = 0.38 * s
	var y_shoulder: float = 0.52 * s
	var y_neck: float = 0.60 * s
	var y_rim: float = 0.68 * s

	var r_belly_low: float = 0.29 * s
	var r_belly_mid: float = 0.31 * s
	var r_shoulder: float = 0.26 * s
	var r_neck: float = 0.18 * s
	var r_rim: float = 0.23 * s

	_build_ngon_frustum(st_body, y_foot, y_belly_low, r_foot, r_belly_low, angles)
	_build_ngon_frustum(st_body, y_belly_low, y_belly_mid, r_belly_low, r_belly_mid, angles)
	_build_ngon_frustum(st_body, y_belly_mid, y_shoulder, r_belly_mid, r_shoulder, angles)
	_build_ngon_frustum(st_body, y_shoulder, y_neck, r_shoulder, r_neck, angles)
	_build_ngon_frustum(st_body, y_neck, y_rim, r_neck, r_rim, angles)

	# 3. Labio superior / Corona acampanada (Rim Lip)
	var y_lip_top: float = y_rim + 0.04 * s
	var r_lip_out: float = r_rim * 1.08
	var r_lip_in: float = r_neck * 0.95
	_build_ngon_frustum(st_trim, y_rim, y_lip_top, r_rim, r_lip_out, angles)

	if config.has_lid:
		# Tapa ligeramente abovedada
		var y_lid_peak: float = y_lip_top + 0.05 * s
		_build_ngon_frustum(st_trim, y_lip_top, y_lid_peak, r_lip_out, 0.05 * s, angles)
		_build_ngon_cap(st_trim, y_lid_peak, 0.05 * s, angles, true)
	else:
		# Interior hueco del brocal
		_build_ngon_frustum(st_trim, y_lip_top, y_rim, r_lip_out, r_lip_in, angles)
		_build_ngon_cap(st_body, y_rim, r_lip_in, angles, false)

	# 4. Bandas horizontales en relieve saliente (Relief Bands - Imagen 1)
	var band_levels: Array[float] = [0.20 * s, 0.36 * s, 0.50 * s]
	var band_h: float = 0.035 * s
	var band_out: float = 0.016 * s

	for b_y in band_levels:
		var r_at_y: float = _interpolate_urn_radius(b_y, s, r_foot, r_belly_low, r_belly_mid, r_shoulder)
		var r_b_out: float = r_at_y + band_out
		_build_ngon_frustum(st_trim, b_y, b_y + band_h * 0.3, r_at_y, r_b_out, angles)
		_build_ngon_frustum(st_trim, b_y + band_h * 0.3, b_y + band_h * 0.7, r_b_out, r_b_out, angles)
		_build_ngon_frustum(st_trim, b_y + band_h * 0.7, b_y + band_h, r_b_out, r_at_y, angles)

	# Finalizar mallas y colisión
	_commit_and_attach_meshes(asset, g_body, st_body, g_trim, st_trim, "BandedUrn", r_belly_mid, y_rim + 0.06 * s, config)

# ==============================================================================
# ESTILO 2: URNA DE CRIPTA CON RELIEVE DE CALAVERA Y TAPA BISELADA (SKULL RELIC URN)
# ==============================================================================

func _build_skull_relic_urn(asset: _GeneratedAssetScript, config: _UrnGeometryConfigScript, angles: Array[float], s: float) -> void:
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Base cónica biselada
	var y_base: float = 0.0
	var y_foot: float = 0.08 * s
	var r_base: float = 0.15 * s
	var r_foot: float = 0.22 * s
	_build_ngon_cap(st_body, y_base, r_base, angles, false)
	_build_ngon_frustum(st_body, y_base, y_foot, r_base, r_foot, angles)

	# 2. Cuerpo troncocónico gótico
	var y_mid: float = 0.36 * s
	var y_shoulder: float = 0.54 * s
	var y_neck: float = 0.62 * s

	var r_mid: float = 0.30 * s
	var r_shoulder: float = 0.28 * s
	var r_neck: float = 0.20 * s

	_build_ngon_frustum(st_body, y_foot, y_mid, r_foot, r_mid, angles)
	_build_ngon_frustum(st_body, y_mid, y_shoulder, r_mid, r_shoulder, angles)
	_build_ngon_frustum(st_body, y_shoulder, y_neck, r_shoulder, r_neck, angles)

	# 3. Tapa cilíndrica sellada con bisel superior (Lid - Imagen 3)
	var y_lid_bot: float = y_neck
	var y_lid_mid: float = y_neck + 0.06 * s
	var y_lid_top: float = y_neck + 0.09 * s
	var r_lid_out: float = 0.24 * s
	var r_lid_top: float = 0.21 * s

	_build_ngon_frustum(st_trim, y_lid_bot, y_lid_mid, r_neck, r_lid_out, angles)
	_build_ngon_frustum(st_trim, y_lid_mid, y_lid_top, r_lid_out, r_lid_top, angles)
	_build_ngon_cap(st_trim, y_lid_top, r_lid_top, angles, true)

	# 4. Relieve frontal de Calavera / Blasón de Cripta en bajorrelieve
	var z_front: float = r_mid * 0.98
	var y_skull_center: float = 0.35 * s
	var skull_w: float = 0.12 * s
	var skull_h: float = 0.14 * s
	var skull_proj: float = 0.024 * s

	# Bóveda craneal
	var p_cranium_top := Vector3(0.0, y_skull_center + skull_h * 0.5, z_front + skull_proj)
	var p_cranium_l := Vector3(-skull_w * 0.5, y_skull_center + skull_h * 0.2, z_front + skull_proj * 0.8)
	var p_cranium_r := Vector3(skull_w * 0.5, y_skull_center + skull_h * 0.2, z_front + skull_proj * 0.8)
	var p_cranium_c := Vector3(0.0, y_skull_center + skull_h * 0.1, z_front + skull_proj)

	_add_triangle_direct(st_trim, p_cranium_l, p_cranium_top, p_cranium_c)
	_add_triangle_direct(st_trim, p_cranium_top, p_cranium_r, p_cranium_c)

	# Cuencas oculares y maxilar
	var p_jaw_l := Vector3(-skull_w * 0.3, y_skull_center - skull_h * 0.4, z_front + skull_proj * 0.7)
	var p_jaw_r := Vector3(skull_w * 0.3, y_skull_center - skull_h * 0.4, z_front + skull_proj * 0.7)
	var p_jaw_c := Vector3(0.0, y_skull_center - skull_h * 0.45, z_front + skull_proj * 0.9)

	_add_triangle_direct(st_trim, p_jaw_l, p_cranium_c, p_jaw_c)
	_add_triangle_direct(st_trim, p_cranium_c, p_jaw_r, p_jaw_c)
	_add_triangle_direct(st_trim, p_cranium_l, p_jaw_l, p_cranium_c)
	_add_triangle_direct(st_trim, p_cranium_r, p_cranium_c, p_jaw_r)

	_commit_and_attach_meshes(asset, g_body, st_body, g_trim, st_trim, "SkullUrn", r_mid, y_lid_top, config)

# ==============================================================================
# ESTILO 3: COPA Y URNA MONUMENTAL CON PEDESTAL (CEREMONIAL PEDESTAL URN)
# ==============================================================================

func _build_ceremonial_pedestal_urn(asset: _GeneratedAssetScript, config: _UrnGeometryConfigScript, angles: Array[float], s: float) -> void:
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Pedestal cuadrado en la base (Plinth)
	var plinth_w: float = 0.36 * s
	var y_plinth_1: float = 0.04 * s
	var y_plinth_2: float = 0.08 * s

	_build_box(st_trim,
		Vector3(-plinth_w * 0.5, 0.0, -plinth_w * 0.5),
		Vector3(plinth_w * 0.5, y_plinth_1, plinth_w * 0.5)
	)
	_build_box(st_trim,
		Vector3(-plinth_w * 0.44, y_plinth_1, -plinth_w * 0.44),
		Vector3(plinth_w * 0.44, y_plinth_2, plinth_w * 0.44)
	)

	# 2. Fuste cónico torneado (Stem)
	var y_stem_bot: float = y_plinth_2
	var y_stem_neck: float = 0.16 * s
	var y_calyx_bot: float = 0.22 * s
	var r_stem_bot: float = 0.14 * s
	var r_stem_neck: float = 0.08 * s
	var r_calyx_bot: float = 0.15 * s

	_build_ngon_frustum(st_trim, y_stem_bot, y_stem_neck, r_stem_bot, r_stem_neck, angles)
	_build_ngon_frustum(st_trim, y_stem_neck, y_calyx_bot, r_stem_neck, r_calyx_bot, angles)

	# 3. Cáliz y cuerpo de copa acampanada (Fluted Goblet/Krater)
	var y_bowl_mid: float = 0.42 * s
	var y_bowl_rim: float = 0.58 * s
	var r_bowl_mid: float = 0.30 * s
	var r_bowl_rim: float = 0.32 * s

	_build_ngon_frustum(st_body, y_calyx_bot, y_bowl_mid, r_calyx_bot, r_bowl_mid, angles)
	_build_ngon_frustum(st_body, y_bowl_mid, y_bowl_rim, r_bowl_mid, r_bowl_rim, angles)

	# Corona moldurada del borde
	var y_rim_lip: float = y_bowl_rim + 0.04 * s
	var r_rim_out: float = r_bowl_rim * 1.08
	_build_ngon_frustum(st_trim, y_bowl_rim, y_rim_lip, r_bowl_rim, r_rim_out, angles)

	# 4. Tapa abovedada con remate en pomo gótico (Lid & Acorn Finial)
	if config.has_lid:
		var y_lid_mid: float = y_rim_lip + 0.08 * s
		var y_finial_base: float = y_rim_lip + 0.14 * s
		var y_finial_top: float = y_rim_lip + 0.22 * s
		var r_finial_base: float = 0.04 * s
		var r_finial_mid: float = 0.06 * s

		_build_ngon_frustum(st_trim, y_rim_lip, y_lid_mid, r_rim_out, 0.18 * s, angles)
		_build_ngon_frustum(st_trim, y_lid_mid, y_finial_base, 0.18 * s, r_finial_base, angles)

		# Pomo / Bellota superior (Acorn)
		_build_ngon_frustum(st_trim, y_finial_base, y_finial_base + 0.04 * s, r_finial_base, r_finial_mid, angles)
		_build_ngon_frustum(st_trim, y_finial_base + 0.04 * s, y_finial_top, r_finial_mid, 0.01 * s, angles)
		_build_ngon_cap(st_trim, y_finial_top, 0.01 * s, angles, true)
	else:
		_build_ngon_cap(st_body, y_rim_lip, r_bowl_rim * 0.9, angles, false)

	_commit_and_attach_meshes(asset, g_body, st_body, g_trim, st_trim, "PedestalUrn", r_bowl_rim, y_bowl_rim + 0.24 * s, config)

# ==============================================================================
# ESTILO 4: FRASCO CANOPO COMPACTO DE MESA (CANOPIC JAR)
# ==============================================================================

func _build_canopic_jar(asset: _GeneratedAssetScript, config: _UrnGeometryConfigScript, angles: Array[float], s: float) -> void:
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Proporciones elegantes para superficies y mesas
	var y_base: float = 0.0
	var y_foot: float = 0.04 * s
	var y_body_mid: float = 0.16 * s
	var y_shoulder: float = 0.28 * s
	var y_neck: float = 0.40 * s
	var y_rim: float = 0.46 * s

	var r_base: float = 0.09 * s
	var r_foot: float = 0.12 * s
	var r_body_mid: float = 0.15 * s
	var r_shoulder: float = 0.13 * s
	var r_neck: float = 0.075 * s
	var r_rim: float = 0.095 * s

	_build_ngon_cap(st_body, y_base, r_base, angles, false)
	_build_ngon_frustum(st_body, y_base, y_foot, r_base, r_foot, angles)
	_build_ngon_frustum(st_body, y_foot, y_body_mid, r_foot, r_body_mid, angles)
	_build_ngon_frustum(st_body, y_body_mid, y_shoulder, r_body_mid, r_shoulder, angles)
	_build_ngon_frustum(st_body, y_shoulder, y_neck, r_shoulder, r_neck, angles)
	_build_ngon_frustum(st_trim, y_neck, y_rim, r_neck, r_rim, angles)

	# Tapa de corcho/sello
	var y_lid_top: float = y_rim + 0.05 * s
	_build_ngon_frustum(st_trim, y_rim, y_lid_top, r_rim, 0.06 * s, angles)
	_build_ngon_cap(st_trim, y_lid_top, 0.06 * s, angles, true)

	_commit_and_attach_meshes(asset, g_body, st_body, g_trim, st_trim, "CanopicJar", r_body_mid, y_lid_top, config)

# ==============================================================================
# HELPERS DE GEOMETRÍA Y MATERIALES
# ==============================================================================

func _commit_and_attach_meshes(
	asset: _GeneratedAssetScript,
	g_body: _GeneratedMeshScript, st_body: SurfaceTool,
	g_trim: _GeneratedMeshScript, st_trim: SurfaceTool,
	asset_name: String, max_radius: float, total_height: float,
	config: _UrnGeometryConfigScript = null
) -> void:
	var preset: int = config.material_preset if config != null else 0
	var style_idx: int = int(config.style) if config != null else 0

	st_body.generate_tangents()
	var mesh_body := ArrayMesh.new()
	mesh_body = st_body.commit(mesh_body)
	mesh_body.surface_set_name(0, "%s_Body" % asset_name)
	g_body.mesh = mesh_body
	g_body.material_slots[0] = _WallMaterialFactoryScript.create_urn_body_material(preset, style_idx)
	asset.add_mesh(&"urn_body", g_body)

	st_trim.generate_tangents()
	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	mesh_trim.surface_set_name(0, "%s_Trim" % asset_name)
	g_trim.mesh = mesh_trim
	g_trim.material_slots[0] = _WallMaterialFactoryScript.create_urn_trim_material(preset, style_idx)
	asset.add_mesh(&"urn_trim", g_trim)

	# Colisión física
	var col_shape := CylinderShape3D.new()
	col_shape.radius = max_radius * 0.95
	col_shape.height = total_height
	g_body.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_height * 0.5, 0.0)))

static func _interpolate_urn_radius(y: float, s: float, r0: float, r1: float, r2: float, r3: float) -> float:
	if y < 0.22 * s:
		var t = y / (0.22 * s)
		return lerpf(r0, r1, t)
	elif y < 0.38 * s:
		var t = (y - 0.22 * s) / (0.16 * s)
		return lerpf(r1, r2, t)
	else:
		var t = (y - 0.38 * s) / (0.14 * s)
		return lerpf(r2, r3, t)

static func _build_box(st: SurfaceTool, min_v: Vector3, max_v: Vector3) -> void:
	var p000 := Vector3(min_v.x, min_v.y, min_v.z)
	var p100 := Vector3(max_v.x, min_v.y, min_v.z)
	var p110 := Vector3(max_v.x, max_v.y, min_v.z)
	var p010 := Vector3(min_v.x, max_v.y, min_v.z)

	var p001 := Vector3(min_v.x, min_v.y, max_v.z)
	var p101 := Vector3(max_v.x, min_v.y, max_v.z)
	var p111 := Vector3(max_v.x, max_v.y, max_v.z)
	var p011 := Vector3(min_v.x, max_v.y, max_v.z)

	_add_quad_direct(st, p000, p010, p110, p100) # Front (-Z)
	_add_quad_direct(st, p101, p111, p011, p001) # Back (+Z)
	_add_quad_direct(st, p000, p100, p101, p001) # Bottom (-Y)
	_add_quad_direct(st, p011, p111, p110, p010) # Top (+Y)
	_add_quad_direct(st, p001, p011, p010, p000) # Left (-X)
	_add_quad_direct(st, p100, p110, p111, p101) # Right (+X)

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

		_add_quad_direct(st, p_b0, p_t0, p_t1, p_b1)

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
			_add_triangle_direct(st, center, p1, p0)
		else:
			_add_triangle_direct(st, center, p0, p1)

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
