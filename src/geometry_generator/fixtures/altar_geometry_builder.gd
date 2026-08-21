class_name AltarGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para el Altar de Piedra de Mazmorra (Stone Altar).
## Geometría modular en longitud, 100% sólida, con normales y devanado CCW garantizados:
## 1. `altar_stone_body`: Núcleo central, paneles rehundidos y zócalos de piedra.
## 2. `altar_stone_trim`: Pedestal escalonado, 4 pilastras de esquina, capiteles y losa superior volada con bisel.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _AltarGeometryConfigScript = preload("res://src/geometry_generator/config/altar_geometry_config.gd")

func build_altar_fixture(config = null):
	if config == null:
		config = _AltarGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_stone_altar"

	var s: float = config.scale_mult
	var len_x: float = config.length * s
	var dep_z: float = config.depth * s
	var total_h: float = config.height * s
	var slab_t: float = config.slab_thickness * s
	var slab_oh: float = config.slab_overhang * s
	var pw: float = config.pilaster_width * s

	var half_len := len_x * 0.5
	var half_dep := dep_z * 0.5

	# Alturas de la composición
	var h_plinth_1: float = 0.045 * s
	var h_plinth_2: float = 0.045 * s
	var h_plinth_total: float = h_plinth_1 + h_plinth_2
	var h_body: float = total_h - h_plinth_total - slab_t
	var body_y_center: float = h_plinth_total + h_body * 0.5
	var slab_y_center: float = total_h - slab_t * 0.5

	# ==========================================================================
	# 1. SUPERFICIE DE PIEDRA PRINCIPAL (CUERPO Y PANELES)
	# ==========================================================================
	var g_body = _GeneratedMeshScript.new()
	g_body.component_id = 0
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Núcleo interior del altar
	var body_inset := 0.025 * s
	_build_solid_box(
		st_body,
		Vector3(0.0, body_y_center, 0.0),
		Vector3(len_x - body_inset * 2.0, h_body, dep_z - body_inset * 2.0)
	)

	# Paneles frontales y traseros rehundidos con relieve
	var panel_thick := 0.020 * s
	var panel_w: float = len_x - pw * 2.1
	var panel_h: float = h_body - 0.060 * s

	# Panel frontal (+Z)
	_build_solid_box(st_body, Vector3(0.0, body_y_center, half_dep - panel_thick * 0.5), Vector3(panel_w, panel_h, panel_thick))
	# Panel trasero (-Z)
	_build_solid_box(st_body, Vector3(0.0, body_y_center, -half_dep + panel_thick * 0.5), Vector3(panel_w, panel_h, panel_thick))
	# Paneles laterales (+X y -X)
	var side_panel_w: float = dep_z - pw * 2.1
	_build_solid_box(st_body, Vector3(half_len - panel_thick * 0.5, body_y_center, 0.0), Vector3(panel_thick, panel_h, side_panel_w))
	_build_solid_box(st_body, Vector3(-half_len + panel_thick * 0.5, body_y_center, 0.0), Vector3(panel_thick, panel_h, side_panel_w))

	var mesh_body := ArrayMesh.new()
	mesh_body = st_body.commit(mesh_body)
	mesh_body.surface_set_name(0, "AltarStoneBody")
	g_body.mesh = mesh_body

	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = config.stone_body_color
	mat_body.roughness = 0.82
	mat_body.metallic = 0.0
	mat_body.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_body.material_slots[0] = mat_body
	asset.add_mesh(&"altar_stone_body", g_body)

	# ==========================================================================
	# 2. SUPERFICIE DE MOLDURAS (PEDESTAL, PILASTRAS, CAPITELES Y LOSA SUPERIOR)
	# ==========================================================================
	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. PEDESTAL ESCALONADO INFERIOR (2 NIVELES + ESCALÓN FRONTAL) ---
	var plinth_1_w: float = len_x + 0.20 * s
	var plinth_1_d: float = dep_z + 0.20 * s
	_build_solid_box(st_trim, Vector3(0.0, h_plinth_1 * 0.5, 0.0), Vector3(plinth_1_w, h_plinth_1, plinth_1_d))

	var plinth_2_w: float = len_x + 0.10 * s
	var plinth_2_d: float = dep_z + 0.10 * s
	_build_solid_box(st_trim, Vector3(0.0, h_plinth_1 + h_plinth_2 * 0.5, 0.0), Vector3(plinth_2_w, h_plinth_2, plinth_2_d))

	# Peldaño frontal central de aproximación
	var step_w: float = len_x * 0.44
	var step_d: float = 0.10 * s
	var step_h: float = h_plinth_1 * 0.90
	_build_solid_box(st_trim, Vector3(0.0, step_h * 0.5, half_dep + 0.10 * s + step_d * 0.5), Vector3(step_w, step_h, step_d))

	# --- B. 4 PILASTRAS DE ESQUINA ROBUSTAS ---
	var pilaster_cx := half_len - pw * 0.5
	var pilaster_cz := half_dep - pw * 0.5

	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var p_pos := Vector3(float(ix) * pilaster_cx, body_y_center, float(iz) * pilaster_cz)
			_build_solid_box(st_trim, p_pos, Vector3(pw * 1.05, h_body, pw * 1.05))

			# Base de la pilastra
			var base_p_h := 0.035 * s
			var base_p_pos := Vector3(float(ix) * pilaster_cx, h_plinth_total + base_p_h * 0.5, float(iz) * pilaster_cz)
			_build_solid_box(st_trim, base_p_pos, Vector3(pw * 1.25, base_p_h, pw * 1.25))

			# Capitel de la pilastra (bajo la losa)
			var cap_h := 0.035 * s
			var cap_pos := Vector3(float(ix) * pilaster_cx, total_h - slab_t - cap_h * 0.5, float(iz) * pilaster_cz)
			_build_solid_box(st_trim, cap_pos, Vector3(pw * 1.25, cap_h, pw * 1.25))

	# --- C. MESA / LOSA SUPERIOR VOLADA CON BISEL (TABLE TOP) ---
	var slab_w: float = len_x + slab_oh * 2.0
	var slab_d: float = dep_z + slab_oh * 2.0
	_build_solid_box(st_trim, Vector3(0.0, slab_y_center, 0.0), Vector3(slab_w, slab_t, slab_d))

	# Moldura de reborde achaflanado en los extremos izquierdo y derecho
	var end_cap_w: float = pw * 1.30
	var end_cap_t: float = 0.025 * s
	var end_cap_d: float = slab_d + 0.020 * s
	var end_cap_y: float = total_h + end_cap_t * 0.5

	_build_solid_box(st_trim, Vector3(-half_len - slab_oh * 0.5 + end_cap_w * 0.35, end_cap_y, 0.0), Vector3(end_cap_w, end_cap_t, end_cap_d))
	_build_solid_box(st_trim, Vector3(half_len + slab_oh * 0.5 - end_cap_w * 0.35, end_cap_y, 0.0), Vector3(end_cap_w, end_cap_t, end_cap_d))

	# Cuenca / Depresión central de ofrendas o sacrificios en la losa superior
	var basin_w: float = 0.22 * s
	var basin_d: float = 0.16 * s
	var basin_depth: float = 0.035 * s
	var basin_y: float = total_h - basin_depth * 0.5
	_build_solid_box(st_trim, Vector3(0.0, basin_y, 0.0), Vector3(basin_w, basin_depth, basin_d))

	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	mesh_trim.surface_set_name(0, "AltarStoneTrim")
	g_trim.mesh = mesh_trim

	var mat_trim := StandardMaterial3D.new()
	mat_trim.albedo_color = config.stone_trim_color
	mat_trim.roughness = 0.74
	mat_trim.metallic = 0.0
	mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_trim.material_slots[0] = mat_trim
	asset.add_mesh(&"altar_stone_trim", g_trim)

	# Colisión
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(slab_w, total_h, slab_d)
	g_body.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

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
