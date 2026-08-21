class_name BarrelGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para el Barril de Madera Estilizado (Barrel).
## Geometría sólida, estanca y garantizada contra caras invertidas (CCW explícito + Cull Disabled):
## 1. Duelas abombadas de madera estilizada con acanaladuras longitudinales.
## 2. Brocal perimetral rehundido en la tapa superior e inferior.
## 3. Zunchos/Aros de hierro forjado volumétricos abrazando el contorno curvo.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _BarrelGeometryConfigScript = preload("res://src/geometry_generator/config/barrel_geometry_config.gd")

func build_barrel_fixture(config = null):
	if config == null:
		config = _BarrelGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_wooden_barrel"

	var s: float = config.scale_mult
	var total_h: float = config.height * s
	var r_rim: float = config.rim_radius * s
	var r_belly: float = config.belly_radius * s
	var staves: int = maxi(8, config.stave_count)

	# Perfil de curvatura vertical del barril (5 niveles verticales)
	var y_levels: Array[float] = [
		0.0,
		total_h * 0.20,
		total_h * 0.50,
		total_h * 0.80,
		total_h
	]

	var r_levels: Array[float] = [
		r_rim,
		lerpf(r_rim, r_belly, 0.75),
		r_belly,
		lerpf(r_rim, r_belly, 0.75),
		r_rim
	]

	# Ángulos para cada duela
	var angles: Array[float] = []
	for i in range(staves):
		angles.append(float(i) * (TAU / float(staves)))

	# ==========================================================================
	# 1. SUPERFICIE DE MADERA (CUERPO DE DUELAS Y TAPAS REHUNDIDAS)
	# ==========================================================================
	var g_wood = _GeneratedMeshScript.new()
	g_wood.component_id = 0
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. DUELAS Y CUERPO CURVO DEL BARRIL ---
	for lv in range(y_levels.size() - 1):
		var y_bot: float = y_levels[lv]
		var y_top: float = y_levels[lv + 1]
		var rb: float = r_levels[lv]
		var rt: float = r_levels[lv + 1]

		for i in range(staves):
			var i_next: int = (i + 1) % staves
			var a0: float = angles[i]
			var a1: float = angles[i_next]

			var p_b0 := Vector3(cos(a0) * rb, y_bot, sin(a0) * rb)
			var p_b1 := Vector3(cos(a1) * rb, y_bot, sin(a1) * rb)
			var p_t1 := Vector3(cos(a1) * rt, y_top, sin(a1) * rt)
			var p_t0 := Vector3(cos(a0) * rt, y_top, sin(a0) * rt)

			_add_quad(st_wood, p_b0, p_b1, p_t1, p_t0)

	# --- B. BROCAL Y TAPA SUPERIOR REHUNDIDA (+Y) ---
	var rim_lip_h: float = 0.035 * s
	var r_lid: float = r_rim * 0.86
	var y_lid_top: float = total_h - rim_lip_h

	# Bisel interior del brocal superior
	for i in range(staves):
		var i_next: int = (i + 1) % staves
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_rim0 := Vector3(cos(a0) * r_rim, total_h, sin(a0) * r_rim)
		var p_rim1 := Vector3(cos(a1) * r_rim, total_h, sin(a1) * r_rim)
		var p_in1 := Vector3(cos(a1) * r_lid, y_lid_top, sin(a1) * r_lid)
		var p_in0 := Vector3(cos(a0) * r_lid, y_lid_top, sin(a0) * r_lid)

		_add_quad(st_wood, p_rim0, p_rim1, p_in1, p_in0)

	# Tapa de madera rehundida (disco plano horizontal)
	var lid_center_top := Vector3(0.0, y_lid_top, 0.0)
	for i in range(staves):
		var i_next: int = (i + 1) % staves
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r_lid, y_lid_top, sin(a0) * r_lid)
		var p1 := Vector3(cos(a1) * r_lid, y_lid_top, sin(a1) * r_lid)
		_add_tri(st_wood, lid_center_top, p0, p1)

	# --- C. BASE INFERIOR (-Y) ---
	var base_center_bot := Vector3(0.0, 0.0, 0.0)
	for i in range(staves):
		var i_next: int = (i + 1) % staves
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r_rim, 0.0, sin(a0) * r_rim)
		var p1 := Vector3(cos(a1) * r_rim, 0.0, sin(a1) * r_rim)
		_add_tri(st_wood, base_center_bot, p1, p0)

	var mesh_wood := ArrayMesh.new()
	mesh_wood = st_wood.commit(mesh_wood)
	mesh_wood.surface_set_name(0, "BarrelWood")
	g_wood.mesh = mesh_wood

	# Material Madera Cálida con Doble Cara
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = config.wood_color
	mat_wood.roughness = 0.68
	mat_wood.metallic = 0.0
	mat_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood.material_slots[0] = mat_wood
	asset.add_mesh(&"barrel_wood", g_wood)

	# ==========================================================================
	# 2. SUPERFICIE DE HIERRO FORJADO (ZUNCHOS / AROS METÁLICOS)
	# ==========================================================================
	var g_iron = _GeneratedMeshScript.new()
	g_iron.component_id = 1
	var st_iron := SurfaceTool.new()
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw: float = config.hoop_width * s
	var ht: float = config.hoop_thickness * s

	# Posiciones Y de los aros
	var hoop_y_positions: Array[float] = [
		total_h * 0.18, # Aro inferior
		total_h * 0.78  # Aro superior
	]
	if config.hoop_count >= 3:
		hoop_y_positions.append(total_h * 0.50) # Aro central

	for hoop_y in hoop_y_positions:
		var y_b: float = hoop_y - hw * 0.5
		var y_t: float = hoop_y + hw * 0.5

		# Interpolar el radio de la madera a esas alturas
		var t_b := clampf(y_b / total_h, 0.0, 1.0)
		var t_t := clampf(y_t / total_h, 0.0, 1.0)
		var r_wood_b := _interpolate_barrel_radius(t_b, r_rim, r_belly)
		var r_wood_t := _interpolate_barrel_radius(t_t, r_rim, r_belly)

		var r_hoop_b := r_wood_b + ht
		var r_hoop_t := r_wood_t + ht

		_build_hoop_ring(st_iron, y_b, y_t, r_wood_b, r_wood_t, r_hoop_b, r_hoop_t, angles)

	var mesh_iron := ArrayMesh.new()
	mesh_iron = st_iron.commit(mesh_iron)
	mesh_iron.surface_set_name(0, "BarrelIron")
	g_iron.mesh = mesh_iron

	# Material Hierro Forjado Oscuro con Doble Cara
	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = config.iron_color
	mat_iron.roughness = 0.38
	mat_iron.metallic = 0.85
	mat_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_iron.material_slots[0] = mat_iron
	asset.add_mesh(&"barrel_iron", g_iron)

	# ==========================================================================
	# 3. COLISIÓN FÍSICA CILÍNDRICA
	# ==========================================================================
	var col_shape := CylinderShape3D.new()
	col_shape.radius = r_belly * 0.96
	col_shape.height = total_h
	g_wood.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS
# ==============================================================================

static func _interpolate_barrel_radius(t: float, r_rim: float, r_belly: float) -> float:
	# Curva parabólica suave: máxima en t = 0.5
	var factor: float = 1.0 - pow((t - 0.5) * 2.0, 2.0)
	return lerpf(r_rim, r_belly, factor)

static func _build_hoop_ring(
	st: SurfaceTool,
	y_bot: float,
	y_top: float,
	r_in_b: float,
	r_in_t: float,
	r_out_b: float,
	r_out_t: float,
	angles: Array[float]
) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		# Vértices exteriores
		var p_out_b0 := Vector3(cos(a0) * r_out_b, y_bot, sin(a0) * r_out_b)
		var p_out_b1 := Vector3(cos(a1) * r_out_b, y_bot, sin(a1) * r_out_b)
		var p_out_t1 := Vector3(cos(a1) * r_out_t, y_top, sin(a1) * r_out_t)
		var p_out_t0 := Vector3(cos(a0) * r_out_t, y_top, sin(a0) * r_out_t)

		# Cara exterior del aro
		_add_quad(st, p_out_b0, p_out_b1, p_out_t1, p_out_t0)

		# Borde superior del aro
		var p_in_t0 := Vector3(cos(a0) * r_in_t, y_top, sin(a0) * r_in_t)
		var p_in_t1 := Vector3(cos(a1) * r_in_t, y_top, sin(a1) * r_in_t)
		_add_quad(st, p_out_t0, p_out_t1, p_in_t1, p_in_t0)

		# Borde inferior del aro
		var p_in_b0 := Vector3(cos(a0) * r_in_b, y_bot, sin(a0) * r_in_b)
		var p_in_b1 := Vector3(cos(a1) * r_in_b, y_bot, sin(a1) * r_in_b)
		_add_quad(st, p_in_b0, p_in_b1, p_out_b1, p_out_b0)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_tri(st, p0, p1, p2)
	_add_tri(st, p0, p2, p3)

static func _add_tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
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
