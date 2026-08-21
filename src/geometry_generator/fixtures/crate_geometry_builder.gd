class_name CrateGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para la Caja de Madera Estilizada (Wooden Crate).
## Separa limpiamente los materiales para conseguir el contraste estilizado deseado:
## 1. `crate_panels`: Madera oscura para el núcleo y los tablones de fondo (6 caras).
## 2. `crate_frame`: Madera más clara y cálida para las 12 vigas perimetrales y las 4 diagonales.
## 3. `crate_iron`: Hierro forjado oscuro para las 8 cantoneras esquineras exteriores.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _CrateGeometryConfigScript = preload("res://src/geometry_generator/config/crate_geometry_config.gd")

func build_crate_fixture(config = null):
	if config == null:
		config = _CrateGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_wooden_crate"

	var s: float = config.scale_mult
	var sz: Vector3 = config.crate_size * s
	var half_sz := sz * 0.5
	var bw: float = config.beam_width * s
	var bd: float = config.beam_depth * s

	# ==========================================================================
	# 1. SUPERFICIE DE MADERA OSCURA (TABLONES DE FONDO Y NÚCLEO)
	# ==========================================================================
	var g_panels = _GeneratedMeshScript.new()
	g_panels.component_id = 0
	var st_panels := SurfaceTool.new()
	st_panels.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. NÚCLEO SÓLIDO PRINCIPAL ---
	var core_sz := Vector3(sz.x - (bd * 1.6), sz.y - (bd * 1.6), sz.z - (bd * 1.6))
	_build_solid_box(st_panels, Vector3(0.0, half_sz.y, 0.0), core_sz)

	# --- B. TABLONES ACANALADOS EN LAS 6 CARAS ---
	var plank_count: int = maxi(2, config.plank_count_per_face)
	var plank_span: float = sz.x - (bw * 1.6)
	var plank_w: float = plank_span / float(plank_count)
	var groove: float = 0.007 * s
	var plank_thick: float = bd * 0.60

	# 1. Caras Verticales (Frontal +Z, Trasera -Z, Derecha +X, Izquierda -X)
	var p_h: float = sz.y - (bw * 1.6)
	for i in range(plank_count):
		var off: float = -plank_span * 0.5 + (float(i) + 0.5) * plank_w
		var w_plank: float = plank_w - groove

		# Frontal (+Z)
		_build_solid_box(st_panels, Vector3(off, half_sz.y, half_sz.z - bd * 0.50), Vector3(w_plank, p_h, plank_thick))
		# Trasera (-Z)
		_build_solid_box(st_panels, Vector3(off, half_sz.y, -half_sz.z + bd * 0.50), Vector3(w_plank, p_h, plank_thick))
		# Derecha (+X)
		_build_solid_box(st_panels, Vector3(half_sz.x - bd * 0.50, half_sz.y, off), Vector3(plank_thick, p_h, w_plank))
		# Izquierda (-X)
		_build_solid_box(st_panels, Vector3(-half_sz.x + bd * 0.50, half_sz.y, off), Vector3(plank_thick, p_h, w_plank))

	# 2. Tapa Superior (+Y) y Base Inferior (-Y)
	for i in range(plank_count):
		var off: float = -plank_span * 0.5 + (float(i) + 0.5) * plank_w
		var w_plank: float = plank_w - groove
		# Tapa Superior (+Y)
		_build_solid_box(st_panels, Vector3(off, sz.y - bd * 0.50, 0.0), Vector3(w_plank, plank_thick, plank_span))
		# Base Inferior (-Y)
		_build_solid_box(st_panels, Vector3(off, bd * 0.50, 0.0), Vector3(w_plank, plank_thick, plank_span))

	var mesh_panels := ArrayMesh.new()
	mesh_panels = st_panels.commit(mesh_panels)
	mesh_panels.surface_set_name(0, "CratePanelsWood")
	g_panels.mesh = mesh_panels

	# Material Madera Oscura de Tablones
	var mat_panel_wood := StandardMaterial3D.new()
	mat_panel_wood.albedo_color = config.panel_wood_color
	mat_panel_wood.roughness = 0.75
	mat_panel_wood.metallic = 0.0
	mat_panel_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_panels.material_slots[0] = mat_panel_wood
	asset.add_mesh(&"crate_panels", g_panels)

	# ==========================================================================
	# 2. SUPERFICIE DE MADERA CLARA (MARCO DE 12 VIGAS Y 4 DIAGONALES)
	# ==========================================================================
	var g_frame = _GeneratedMeshScript.new()
	g_frame.component_id = 1
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)

	var x0 := -half_sz.x + bw * 0.5
	var x1 := half_sz.x - bw * 0.5
	var y_bot := bw * 0.5
	var y_top := sz.y - bw * 0.5
	var z0 := -half_sz.z + bw * 0.5
	var z1 := half_sz.z - bw * 0.5

	# 4 Postes Verticales (Esquinas)
	_build_solid_box(st_frame, Vector3(x0, half_sz.y, z0), Vector3(bw, sz.y, bw))
	_build_solid_box(st_frame, Vector3(x1, half_sz.y, z0), Vector3(bw, sz.y, bw))
	_build_solid_box(st_frame, Vector3(x0, half_sz.y, z1), Vector3(bw, sz.y, bw))
	_build_solid_box(st_frame, Vector3(x1, half_sz.y, z1), Vector3(bw, sz.y, bw))

	# 4 Rieles Inferiores Horizontales
	_build_solid_box(st_frame, Vector3(0.0, y_bot, z0), Vector3(sz.x - bw * 2.0, bw, bw))
	_build_solid_box(st_frame, Vector3(0.0, y_bot, z1), Vector3(sz.x - bw * 2.0, bw, bw))
	_build_solid_box(st_frame, Vector3(x0, y_bot, 0.0), Vector3(bw, bw, sz.z - bw * 2.0))
	_build_solid_box(st_frame, Vector3(x1, y_bot, 0.0), Vector3(bw, bw, sz.z - bw * 2.0))

	# 4 Rieles Superiores Horizontales
	_build_solid_box(st_frame, Vector3(0.0, y_top, z0), Vector3(sz.x - bw * 2.0, bw, bw))
	_build_solid_box(st_frame, Vector3(0.0, y_top, z1), Vector3(sz.x - bw * 2.0, bw, bw))
	_build_solid_box(st_frame, Vector3(x0, y_top, 0.0), Vector3(bw, bw, sz.z - bw * 2.0))
	_build_solid_box(st_frame, Vector3(x1, y_top, 0.0), Vector3(bw, bw, sz.z - bw * 2.0))

	# 4 Refuerzos Diagonales Anchos
	if config.diagonal_style != _CrateGeometryConfigScript.DiagonalStyle.NONE:
		var diag_thick: float = bd * 0.90
		var diag_w: float = bw * 1.05
		var diag_span: float = sz.x - bw * 1.8

		# Frontal (+Z)
		_build_solid_diagonal_beam(
			st_frame,
			Vector3(-diag_span * 0.5, sz.y - bw * 0.9, half_sz.z - bd * 0.15),
			Vector3(diag_span * 0.5, bw * 0.9, half_sz.z - bd * 0.15),
			diag_w, diag_thick, Vector3(0, 0, 1)
		)
		# Trasera (-Z)
		_build_solid_diagonal_beam(
			st_frame,
			Vector3(diag_span * 0.5, sz.y - bw * 0.9, -half_sz.z + bd * 0.15),
			Vector3(-diag_span * 0.5, bw * 0.9, -half_sz.z + bd * 0.15),
			diag_w, diag_thick, Vector3(0, 0, -1)
		)
		# Derecha (+X)
		_build_solid_diagonal_beam(
			st_frame,
			Vector3(half_sz.x - bd * 0.15, sz.y - bw * 0.9, -diag_span * 0.5),
			Vector3(half_sz.x - bd * 0.15, bw * 0.9, diag_span * 0.5),
			diag_w, diag_thick, Vector3(1, 0, 0)
		)
		# Izquierda (-X)
		_build_solid_diagonal_beam(
			st_frame,
			Vector3(-half_sz.x + bd * 0.15, sz.y - bw * 0.9, diag_span * 0.5),
			Vector3(-half_sz.x + bd * 0.15, bw * 0.9, -diag_span * 0.5),
			diag_w, diag_thick, Vector3(-1, 0, 0)
		)

	var mesh_frame := ArrayMesh.new()
	mesh_frame = st_frame.commit(mesh_frame)
	mesh_frame.surface_set_name(0, "CrateFrameWood")
	g_frame.mesh = mesh_frame

	# Material Madera Clara/Cálida del Marco y Diagonales
	var mat_frame_wood := StandardMaterial3D.new()
	mat_frame_wood.albedo_color = config.frame_wood_color
	mat_frame_wood.roughness = 0.65
	mat_frame_wood.metallic = 0.0
	mat_frame_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_frame.material_slots[0] = mat_frame_wood
	asset.add_mesh(&"crate_frame", g_frame)

	# ==========================================================================
	# 3. SUPERFICIE DE HIERRO FORJADO (8 CANTONERAS ESQUINERAS)
	# ==========================================================================
	var g_iron = _GeneratedMeshScript.new()
	g_iron.component_id = 2
	var st_iron := SurfaceTool.new()
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 8 Cantoneras de Esquina Volumétricas
	var cap_size: float = bw * 1.02
	for ix in [-1, 1]:
		for iy in [-1, 1]:
			for iz in [-1, 1]:
				var corner_center := Vector3(
					float(ix) * (half_sz.x - cap_size * 0.49),
					(cap_size * 0.49) if iy == -1 else (sz.y - cap_size * 0.49),
					float(iz) * (half_sz.z - cap_size * 0.49)
				)
				_build_solid_box(st_iron, corner_center, Vector3(cap_size, cap_size, cap_size))

	var mesh_iron := ArrayMesh.new()
	mesh_iron = st_iron.commit(mesh_iron)
	mesh_iron.surface_set_name(0, "CrateIron")
	g_iron.mesh = mesh_iron

	# Material Hierro Forjado Gris Oscuro
	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = config.iron_color
	mat_iron.roughness = 0.38
	mat_iron.metallic = 0.85
	mat_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_iron.material_slots[0] = mat_iron
	asset.add_mesh(&"crate_iron", g_iron)

	# Colisión
	var col_shape := BoxShape3D.new()
	col_shape.size = sz
	g_frame.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, half_sz.y, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS 100% VOLUMÉTRICOS CON NORMALES DIRIGIDAS
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

static func _build_solid_diagonal_beam(
	st: SurfaceTool,
	p_start: Vector3,
	p_end: Vector3,
	width: float,
	thickness: float,
	face_normal: Vector3
) -> void:
	var dir := (p_end - p_start).normalized()
	var side := face_normal.cross(dir).normalized()
	var out := face_normal * (thickness * 0.5)

	# 8 vertices del prisma diagonal
	var a_b_back := p_start - (side * width * 0.5) - out
	var b_b_back := p_start + (side * width * 0.5) - out
	var b_t_back := p_end + (side * width * 0.5) - out
	var a_t_back := p_end - (side * width * 0.5) - out

	var a_b_front := p_start - (side * width * 0.5) + out
	var b_b_front := p_start + (side * width * 0.5) + out
	var b_t_front := p_end + (side * width * 0.5) + out
	var a_t_front := p_end - (side * width * 0.5) + out

	# Cara frontal exterior (+out)
	_add_quad_facing(st, a_b_front, b_b_front, b_t_front, a_t_front, face_normal)
	# Cara trasera interior (-out)
	_add_quad_facing(st, b_b_back, a_b_back, a_t_back, b_t_back, -face_normal)
	# Lateral 1 (+side)
	_add_quad_facing(st, b_b_front, b_b_back, b_t_back, b_t_front, side)
	# Lateral 2 (-side)
	_add_quad_facing(st, a_b_back, a_b_front, a_t_front, a_t_back, -side)

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
