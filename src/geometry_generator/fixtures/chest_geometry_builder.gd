class_name ChestGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para el Cofre de Mazmorra Estilizado (Stylized Chest).
## Genera el cofre en 2 partes mecánicas articulables:
## 1. `chest_base`: Cajón inferior hueco con interior, marcos de madera, cantoneras y bocallave.
## 2. `chest_lid`: Tapa abovedada con costillas de hierro y pestillo, con pivote exacto en la bisagra trasera.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _ChestGeometryConfigScript = preload("res://src/geometry_generator/config/chest_geometry_config.gd")

func build_chest_fixture(config = null):
	if config == null:
		config = _ChestGeometryConfigScript.new()

	var base_asset = build_chest_base(config)
	var lid_asset = build_chest_lid(config)

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_chest_assembled"

	# Combinar slots de la base
	for slot_name in base_asset.meshes:
		asset.add_mesh(slot_name, base_asset.meshes[slot_name])

	# Combinar slots de la tapa (con prefijo lid_)
	for slot_name in lid_asset.meshes:
		asset.add_mesh(slot_name, lid_asset.meshes[slot_name])

	return asset

# ==============================================================================
# 1. CONSTRUCTOR DEL CAJÓN BASE INFERIOR (CHEST BASE)
# ==============================================================================

func build_chest_base(config = null):
	if config == null:
		config = _ChestGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"chest_base"

	var s: float = config.scale_mult
	var w: float = config.width * s
	var d: float = config.depth * s
	var h: float = config.base_height * s
	var wt: float = config.wall_thickness * s
	var rw: float = config.rim_width * s

	var half_w := w * 0.5
	var half_d := d * 0.5

	# --------------------------------------------------------------------------
	# A. MADERA OSCURA (FONDO, PAREDES INTERIORES Y PANELES)
	# --------------------------------------------------------------------------
	var g_wood_dark = _GeneratedMeshScript.new()
	g_wood_dark.component_id = 0
	var st_wd := SurfaceTool.new()
	st_wd.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Suelo/Fondo del cofre
	_build_solid_box(st_wd, Vector3(0.0, wt * 0.5, 0.0), Vector3(w, wt, d))

	# 4 Paredes del cajón
	var wall_h := h - wt
	var wall_y := wt + wall_h * 0.5
	var inner_w := w - wt * 2.0
	var inner_d := d - wt * 2.0

	# Pared Frontal (+Z) y Trasera (-Z)
	_build_solid_box(st_wd, Vector3(0.0, wall_y, half_d - wt * 0.5), Vector3(w, wall_h, wt))
	_build_solid_box(st_wd, Vector3(0.0, wall_y, -half_d + wt * 0.5), Vector3(w, wall_h, wt))

	# Paredes Laterales (+X y -X)
	_build_solid_box(st_wd, Vector3(half_w - wt * 0.5, wall_y, 0.0), Vector3(wt, wall_h, inner_d))
	_build_solid_box(st_wd, Vector3(-half_w + wt * 0.5, wall_y, 0.0), Vector3(wt, wall_h, inner_d))

	var mesh_wd := ArrayMesh.new()
	mesh_wd = st_wd.commit(mesh_wd)
	mesh_wd.surface_set_name(0, "ChestBaseWoodDark")
	g_wood_dark.mesh = mesh_wd

	var mat_wd := StandardMaterial3D.new()
	mat_wd.albedo_color = config.panel_wood_color
	mat_wd.roughness = 0.72
	mat_wd.metallic = 0.0
	mat_wd.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood_dark.material_slots[0] = mat_wd
	asset.add_mesh(&"chest_base_wood_dark", g_wood_dark)

	# --------------------------------------------------------------------------
	# B. MADERA CLARA (MARCOS Y LISTONES BISELADOS)
	# --------------------------------------------------------------------------
	var g_wood_light = _GeneratedMeshScript.new()
	g_wood_light.component_id = 1
	var st_wl := SurfaceTool.new()
	st_wl.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4 Postes Verticales Exteriores
	var post_w := rw * 0.90
	var post_d := wt * 1.15
	var px := half_w - post_w * 0.5
	var pz := half_d - post_w * 0.5

	_build_solid_box(st_wl, Vector3(px, h * 0.5, pz), Vector3(post_w, h, post_w))
	_build_solid_box(st_wl, Vector3(-px, h * 0.5, pz), Vector3(post_w, h, post_w))
	_build_solid_box(st_wl, Vector3(px, h * 0.5, -pz), Vector3(post_w, h, post_w))
	_build_solid_box(st_wl, Vector3(-px, h * 0.5, -pz), Vector3(post_w, h, post_w))

	# Moldura de reborde superior del cajón
	var rim_thick := wt * 1.10
	_build_solid_box(st_wl, Vector3(0.0, h - rw * 0.45, half_d + 0.002 * s), Vector3(w, rw * 0.90, rw * 0.40))
	_build_solid_box(st_wl, Vector3(0.0, h - rw * 0.45, -half_d - 0.002 * s), Vector3(w, rw * 0.90, rw * 0.40))
	_build_solid_box(st_wl, Vector3(half_w + 0.002 * s, h - rw * 0.45, 0.0), Vector3(rw * 0.40, rw * 0.90, d))
	_build_solid_box(st_wl, Vector3(-half_w - 0.002 * s, h - rw * 0.45, 0.0), Vector3(rw * 0.40, rw * 0.90, d))

	var mesh_wl := ArrayMesh.new()
	mesh_wl = st_wl.commit(mesh_wl)
	mesh_wl.surface_set_name(0, "ChestBaseWoodLight")
	g_wood_light.mesh = mesh_wl

	var mat_wl := StandardMaterial3D.new()
	mat_wl.albedo_color = config.frame_wood_color
	mat_wl.roughness = 0.65
	mat_wl.metallic = 0.0
	mat_wl.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood_light.material_slots[0] = mat_wl
	asset.add_mesh(&"chest_base_wood_light", g_wood_light)

	# --------------------------------------------------------------------------
	# C. HIERRO FORJADO / METAL (4 CANTONERAS INFERIORES Y BOCALLAVE)
	# --------------------------------------------------------------------------
	var g_metal = _GeneratedMeshScript.new()
	g_metal.component_id = 2
	var st_met := SurfaceTool.new()
	st_met.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4 Cantoneras Inferiores
	var cap_sz := rw * 1.35
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var cap_pos := Vector3(
				float(ix) * (half_w - cap_sz * 0.48),
				cap_sz * 0.48,
				float(iz) * (half_d - cap_sz * 0.48)
			)
			_build_solid_box(st_met, cap_pos, Vector3(cap_sz, cap_sz, cap_sz))

	# Placa frontal de Cerradura y Bocallave
	var lock_w: float = 0.12 * s
	var lock_h: float = 0.14 * s
	var lock_d: float = 0.024 * s
	var lock_center := Vector3(0.0, h - lock_h * 0.50, half_d + lock_d * 0.5)
	_build_solid_box(st_met, lock_center, Vector3(lock_w, lock_h, lock_d))

	# Bocallave oscura (pequeño prisma frontal)
	_build_solid_box(st_met, lock_center + Vector3(0.0, -0.015 * s, lock_d * 0.5 + 0.002 * s), Vector3(0.024 * s, 0.050 * s, 0.006 * s))

	var mesh_met := ArrayMesh.new()
	mesh_met = st_met.commit(mesh_met)
	mesh_met.surface_set_name(0, "ChestBaseMetal")
	g_metal.mesh = mesh_met

	var mat_met := StandardMaterial3D.new()
	mat_met.albedo_color = config.metal_color
	mat_met.roughness = 0.35
	mat_met.metallic = 0.88
	mat_met.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_metal.material_slots[0] = mat_met
	asset.add_mesh(&"chest_base_metal", g_metal)

	# Colisión
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(w, h, d)
	g_wood_dark.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, h * 0.5, 0.0)))

	return asset

# ==============================================================================
# 2. CONSTRUCTOR DE LA TAPA ABOVEDADA (CHEST LID)
# Origen Local (0,0,0) situado exactamente en la BISAGRA TRASERA
# ==============================================================================

func build_chest_lid(config = null):
	if config == null:
		config = _ChestGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"chest_lid"

	var s: float = config.scale_mult
	var w: float = config.width * s
	var d: float = config.depth * s
	var lid_h: float = config.lid_height * s
	var wt: float = config.wall_thickness * s
	var rw: float = config.rim_width * s

	var half_w := w * 0.5
	var segments: int = 8

	# Ángulos de la bóveda: de 0 (bisagra trasera z=0) a PI (frente z=d)
	var z_rad := d * 0.5
	var pts_outer: Array[Vector2] = [] # (z, y)
	var pts_inner: Array[Vector2] = []

	for i in range(segments + 1):
		var theta: float = float(i) * (PI / float(segments))
		var zo: float = z_rad - cos(theta) * z_rad
		var yo: float = sin(theta) * lid_h
		pts_outer.append(Vector2(zo, yo))

		var zi: float = z_rad - cos(theta) * (z_rad - wt)
		var yi: float = sin(theta) * (lid_h - wt)
		pts_inner.append(Vector2(zi, yi))

	# --------------------------------------------------------------------------
	# A. MADERA OSCURA (BÓVEDA DE LA TAPA Y TIMPANOS LATERALES)
	# --------------------------------------------------------------------------
	var g_wood_dark = _GeneratedMeshScript.new()
	g_wood_dark.component_id = 0
	var st_wd := SurfaceTool.new()
	st_wd.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Bóveda cilíndrica exterior
	for i in range(segments):
		var p0 := pts_outer[i]
		var p1 := pts_outer[i + 1]

		var v_bl := Vector3(-half_w, p0.y, p0.x)
		var v_br := Vector3(half_w, p0.y, p0.x)
		var v_tr := Vector3(half_w, p1.y, p1.x)
		var v_tl := Vector3(-half_w, p1.y, p1.x)

		var normal := Vector3(0.0, (p0.y + p1.y) * 0.5, (p0.x + p1.x) * 0.5 - z_rad).normalized()
		_add_quad_facing(st_wd, v_bl, v_br, v_tr, v_tl, normal)

	# Bóveda cilíndrica interior (cóncava)
	for i in range(segments):
		var p0 := pts_inner[i]
		var p1 := pts_inner[i + 1]

		var v_bl := Vector3(-half_w + wt, p0.y, p0.x)
		var v_br := Vector3(half_w - wt, p0.y, p0.x)
		var v_tr := Vector3(half_w - wt, p1.y, p1.x)
		var v_tl := Vector3(-half_w + wt, p1.y, p1.x)

		var normal := -Vector3(0.0, (p0.y + p1.y) * 0.5, (p0.x + p1.x) * 0.5 - z_rad).normalized()
		_add_quad_facing(st_wd, v_br, v_bl, v_tl, v_tr, normal)

	# Tímpanos Semicirculares Laterales (+X y -X)
	var center_left := Vector3(-half_w + wt * 0.5, 0.0, z_rad)
	var center_right := Vector3(half_w - wt * 0.5, 0.0, z_rad)

	for i in range(segments):
		var p0 := pts_outer[i]
		var p1 := pts_outer[i + 1]

		# Tímpano Derecho (+X)
		var pr_0 := Vector3(half_w, p0.y, p0.x)
		var pr_1 := Vector3(half_w, p1.y, p1.x)
		var pr_bot := Vector3(half_w, 0.0, z_rad)
		_add_tri_facing(st_wd, pr_bot, pr_0, pr_1, Vector3(1, 0, 0))

		# Tímpano Izquierdo (-X)
		var pl_0 := Vector3(-half_w, p0.y, p0.x)
		var pl_1 := Vector3(-half_w, p1.y, p1.x)
		var pl_bot := Vector3(-half_w, 0.0, z_rad)
		_add_tri_facing(st_wd, pl_bot, pl_1, pl_0, Vector3(-1, 0, 0))

	# Rebordes planos inferiores de la tapa (sellado perimetral)
	_build_solid_box(st_wd, Vector3(0.0, -0.008 * s, d - wt * 0.5), Vector3(w, 0.016 * s, wt))
	_build_solid_box(st_wd, Vector3(0.0, -0.008 * s, wt * 0.5), Vector3(w, 0.016 * s, wt))

	var mesh_wd := ArrayMesh.new()
	mesh_wd = st_wd.commit(mesh_wd)
	mesh_wd.surface_set_name(0, "ChestLidWoodDark")
	g_wood_dark.mesh = mesh_wd

	var mat_wd := StandardMaterial3D.new()
	mat_wd.albedo_color = config.panel_wood_color
	mat_wd.roughness = 0.72
	mat_wd.metallic = 0.0
	mat_wd.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood_dark.material_slots[0] = mat_wd
	asset.add_mesh(&"chest_lid_wood_dark", g_wood_dark)

	# --------------------------------------------------------------------------
	# B. HIERRO FORJADO / METAL (ZUNCHOS ARQUEADOS Y PESTILLO)
	# --------------------------------------------------------------------------
	var g_metal = _GeneratedMeshScript.new()
	g_metal.component_id = 1
	var st_met := SurfaceTool.new()
	st_met.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 3 Zunchos Arqueados (Izquierdo, Central, Derecho)
	var band_w: float = rw * 0.95
	var band_t: float = 0.012 * s
	var x_positions: Array[float] = [
		-half_w + band_w * 0.60,
		0.0,
		half_w - band_w * 0.60
	]

	for band_x in x_positions:
		for i in range(segments):
			var p0 := pts_outer[i]
			var p1 := pts_outer[i + 1]

			var n0 := Vector3(0.0, p0.y, p0.x - z_rad).normalized()
			var n1 := Vector3(0.0, p1.y, p1.x - z_rad).normalized()

			var b0 := Vector3(band_x, p0.y, p0.x) + n0 * band_t
			var b1 := Vector3(band_x, p1.y, p1.x) + n1 * band_t

			var v_bl := b0 - Vector3(band_w * 0.5, 0, 0)
			var v_br := b0 + Vector3(band_w * 0.5, 0, 0)
			var v_tr := b1 + Vector3(band_w * 0.5, 0, 0)
			var v_tl := b1 - Vector3(band_w * 0.5, 0, 0)

			_add_quad_facing(st_met, v_bl, v_br, v_tr, v_tl, (n0 + n1).normalized())

	# Placa frontal de Pestillo (cuelga sobre la cerradura de la base)
	var clasp_w: float = 0.080 * s
	var clasp_h: float = 0.090 * s
	var clasp_t: float = 0.018 * s
	var clasp_pos := Vector3(0.0, -clasp_h * 0.35, d + clasp_t * 0.5)
	_build_solid_box(st_met, clasp_pos, Vector3(clasp_w, clasp_h, clasp_t))

	var mesh_met := ArrayMesh.new()
	mesh_met = st_met.commit(mesh_met)
	mesh_met.surface_set_name(0, "ChestLidMetal")
	g_metal.mesh = mesh_met

	var mat_met := StandardMaterial3D.new()
	mat_met.albedo_color = config.metal_color
	mat_met.roughness = 0.35
	mat_met.metallic = 0.88
	mat_met.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_metal.material_slots[0] = mat_met
	asset.add_mesh(&"chest_lid_metal", g_metal)

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS
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
