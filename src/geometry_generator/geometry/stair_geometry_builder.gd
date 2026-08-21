class_name StairGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para escaleras de piedra de mazmorra (Fase M2 & Arquitectura Unificada).
## Construye un GeneratedMesh con peldaños de mampostería ("StairSteps"), pretiles/zancas laterales ("StairStringers")
## y cajas de colisión escalonadas.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_stair_mesh(config = null):
	if config == null:
		config = _StairGeometryConfigScript.new()

	var g_mesh = _GeneratedMeshScript.new()
	g_mesh.component_id = 0

	var st_steps := SurfaceTool.new()
	var st_railings := SurfaceTool.new()

	st_steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_railings.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tile_size: float = config.tile_size
	var stair_rise: float = config.stair_rise
	var is_downward: bool = config.is_downward
	var num_steps: int = maxi(2, config.num_steps)

	var step_depth: float = (tile_size * 0.85) / float(num_steps)
	var step_height: float = stair_rise / float(num_steps)
	var step_width: float = tile_size * 0.70
	var half_w: float = step_width * 0.5
	var start_z: float = -(tile_size * 0.85) * 0.5

	# 1. GENERAR LOS PELDAÑOS (STEPS)
	for i in range(num_steps):
		var y0: float = float(i) * step_height
		var y1: float = float(i + 1) * step_height
		var z0: float = start_z + (float(i) * step_depth)
		var z1: float = start_z + (float(i + 1) * step_depth)

		if is_downward:
			y0 = -y0
			y1 = -y1

		# Huella horizontal del peldaño (Tread)
		if not is_downward:
			_add_quad(st_steps,
				Vector3(-half_w, y1, z0),
				Vector3(half_w, y1, z0),
				Vector3(half_w, y1, z1),
				Vector3(-half_w, y1, z1)
			)
			# Contrahuella vertical (Riser)
			_add_quad(st_steps,
				Vector3(-half_w, y0, z0),
				Vector3(half_w, y0, z0),
				Vector3(half_w, y1, z0),
				Vector3(-half_w, y1, z0)
			)
		else:
			_add_quad(st_steps,
				Vector3(-half_w, y1, z1),
				Vector3(half_w, y1, z1),
				Vector3(half_w, y1, z0),
				Vector3(-half_w, y1, z0)
			)
			_add_quad(st_steps,
				Vector3(-half_w, y1, z0),
				Vector3(half_w, y1, z0),
				Vector3(half_w, y0, z0),
				Vector3(-half_w, y0, z0)
			)

	# 2. GENERAR PRETILES / ZANCAS LATERALES (STRINGERS)
	var stringer_w: float = config.stringer_width
	var stringer_h: float = config.stringer_height
	var end_z: float = start_z + (float(num_steps) * step_depth)
	var top_y: float = -stair_rise if is_downward else stair_rise

	# Zanca izquierda
	_build_side_stringer(st_railings, -half_w - stringer_w, -half_w, start_z, end_z, 0.0, top_y, stringer_h, is_downward)
	# Zanca derecha
	_build_side_stringer(st_railings, half_w, half_w + stringer_w, start_z, end_z, 0.0, top_y, stringer_h, is_downward)

	# 3. COMMIT DE SUPERFICIES Y MATERIALES PBR
	var mesh := ArrayMesh.new()
	st_steps.generate_tangents()
	mesh = st_steps.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "StairSteps")

	st_railings.generate_tangents()
	mesh = st_railings.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "StairStringers")

	g_mesh.mesh = mesh
	var min_y: float = -stair_rise if is_downward else 0.0
	var max_y: float = 0.0 if is_downward else stair_rise + stringer_h
	g_mesh.bounds = AABB(Vector3(-half_w - stringer_w, min_y, start_z), Vector3((half_w + stringer_w) * 2.0, max_y - min_y, end_z - start_z))

	g_mesh.material_slots[0] = _WallMaterialFactoryScript.create_floor_slab_material()
	if mesh.get_surface_count() > 1:
		g_mesh.material_slots[1] = _WallMaterialFactoryScript.create_trim_material()

	# 4. COLISIONES ESCALONADAS FÍSICAS
	for i in range(num_steps):
		var y_mid: float = (float(i) + 0.5) * step_height
		var z_mid: float = start_z + ((float(i) + 0.5) * step_depth)
		if is_downward:
			y_mid = -y_mid

		var col_step := BoxShape3D.new()
		col_step.size = Vector3(step_width + (stringer_w * 2.0), step_height, step_depth)
		g_mesh.add_collision_shape(col_step, Transform3D(Basis(), Vector3(0.0, y_mid, z_mid)))

	return g_mesh

# ==============================================================================
# SUB-CONSTRUCTORES DE ZANCAS Y QUADS
# ==============================================================================

static func _build_side_stringer(
	st: SurfaceTool, x_min: float, x_max: float, z_start: float, z_end: float,
	y_start: float, y_end: float, height: float, is_downward: bool
) -> void:
	var v_bot_start := Vector3(x_min, y_start, z_start)
	var v_bot_end := Vector3(x_min, y_end, z_end)
	var v_top_start := Vector3(x_min, y_start + height, z_start)
	var v_top_end := Vector3(x_min, y_end + height, z_end)

	var v_bot_start_r := Vector3(x_max, y_start, z_start)
	var v_bot_end_r := Vector3(x_max, y_end, z_end)
	var v_top_start_r := Vector3(x_max, y_start + height, z_start)
	var v_top_end_r := Vector3(x_max, y_end + height, z_end)

	# Cara superior de la zanca
	_add_quad(st, v_top_start, v_top_start_r, v_top_end_r, v_top_end)
	# Cara exterior izquierda
	_add_quad(st, v_bot_start, v_top_start, v_top_end, v_bot_end)
	# Cara interior derecha
	_add_quad(st, v_bot_end_r, v_top_end_r, v_top_start_r, v_bot_start_r)
	# Remates frontal y posterior
	_add_quad(st, v_bot_start, v_bot_start_r, v_top_start_r, v_top_start)
	_add_quad(st, v_bot_end_r, v_bot_end, v_top_end, v_top_end_r)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle(st, p0, p1, p2)
	_add_triangle(st, p0, p2, p3)

static func _add_triangle(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
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
