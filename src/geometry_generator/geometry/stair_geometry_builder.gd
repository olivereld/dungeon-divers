class_name StairGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de alta fidelidad para escaleras góticas estilizadas (Fase M2).
## Recrea fielmente la topología de la referencia de Blender:
## 1. Zócalo / moldura perimetral inferior con bisel a 45° ("Trims").
## 2. Pretiles/zancas laterales inclinadas con pasamanos biselado ("WallPanel" y "Trims").
## 3. Peldaños de losa de piedra con remate de huella y canto biselado ("StairSteps").
## 4. Ladrillos de mampostería en relieve en las paredes laterales ("Bricks").
## 5. Cajas de colisión físicas compuestas para peldaños y zancas.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_stair_mesh(config = null):
	if config == null:
		config = _StairGeometryConfigScript.new()

	var g_mesh = _GeneratedMeshScript.new()
	g_mesh.component_id = 0

	var st_steps := SurfaceTool.new()
	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()
	var st_bricks := SurfaceTool.new()

	st_steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tile_size: float = config.tile_size
	var stair_rise: float = config.stair_rise
	var is_downward: bool = config.is_downward
	var num_steps: int = maxi(2, config.num_steps)

	var stringer_w: float = config.stringer_width
	var stringer_h: float = config.stringer_height
	var bot_trim_h: float = config.bottom_trim_height
	var bot_slope_h: float = config.bottom_trim_slope_height
	var overhang: float = config.trim_overhang

	var step_w: float = tile_size * 0.70
	var half_w: float = step_w * 0.5
	var total_w: float = step_w + (stringer_w * 2.0)
	var half_tot_w: float = total_w * 0.5

	var total_depth: float = tile_size * 0.90
	var step_depth: float = total_depth / float(num_steps)
	var step_height: float = stair_rise / float(num_steps)
	var start_z: float = -(total_depth * 0.5)
	var end_z: float = total_depth * 0.5

	# ==========================================================================
	# 1. ZÓCALO / MOLDURA INFERIOR PERIMETRAL (TRIMS)
	# ==========================================================================
	var h_main: float = bot_trim_h - bot_slope_h
	var y_bot: float = -stair_rise if is_downward else 0.0
	var y_mid: float = y_bot + h_main
	var y_top_trim: float = y_bot + bot_trim_h

	# Zócalo lado izquierdo
	_build_side_bottom_trim(st_trims, -half_tot_w - overhang, -half_tot_w, -half_w, start_z, end_z, y_bot, y_mid, y_top_trim, -1.0)
	# Zócalo lado derecho
	_build_side_bottom_trim(st_trims, half_tot_w, half_tot_w + overhang, half_w, start_z, end_z, y_bot, y_mid, y_top_trim, 1.0)

	# Zócalo frontal izquierdo
	_add_quad_direct(st_trims, Vector3(-half_tot_w - overhang, y_bot, start_z), Vector3(-half_w, y_bot, start_z), Vector3(-half_w, y_mid, start_z), Vector3(-half_tot_w - overhang, y_mid, start_z))
	_add_quad_direct(st_trims, Vector3(-half_tot_w - overhang, y_mid, start_z), Vector3(-half_w, y_mid, start_z), Vector3(-half_w, y_top_trim, start_z), Vector3(-half_tot_w, y_top_trim, start_z))

	# Zócalo frontal derecho
	_add_quad_direct(st_trims, Vector3(half_w, y_bot, start_z), Vector3(half_tot_w + overhang, y_bot, start_z), Vector3(half_tot_w + overhang, y_mid, start_z), Vector3(half_w, y_mid, start_z))
	_add_quad_direct(st_trims, Vector3(half_w, y_mid, start_z), Vector3(half_tot_w + overhang, y_mid, start_z), Vector3(half_tot_w, y_top_trim, start_z), Vector3(half_w, y_top_trim, start_z))

	# Zócalo posterior continuo
	_add_quad_direct(st_trims, Vector3(half_tot_w + overhang, y_bot, end_z), Vector3(-half_tot_w - overhang, y_bot, end_z), Vector3(-half_tot_w - overhang, y_mid, end_z), Vector3(half_tot_w + overhang, y_mid, end_z))
	_add_quad_direct(st_trims, Vector3(half_tot_w + overhang, y_mid, end_z), Vector3(-half_tot_w - overhang, y_mid, end_z), Vector3(-half_tot_w, y_top_trim, end_z), Vector3(half_tot_w, y_top_trim, end_z))

	# Fondo plano inferior
	_add_quad_direct(st_trims, Vector3(-half_tot_w - overhang, y_bot, end_z), Vector3(half_tot_w + overhang, y_bot, end_z), Vector3(half_tot_w + overhang, y_bot, start_z), Vector3(-half_tot_w - overhang, y_bot, start_z))

	# ==========================================================================
	# 2. PELDAÑOS DE PIEDRA ESTILIZADOS CON BISEL (STEPS)
	# ==========================================================================
	var bevel: float = config.step_bevel

	for i in range(num_steps):
		var y0: float = float(i) * step_height
		var y1: float = float(i + 1) * step_height
		var z0: float = start_z + (float(i) * step_depth)
		var z1: float = start_z + (float(i + 1) * step_depth)

		if is_downward:
			y0 = -y0
			y1 = -y1

		if not is_downward:
			# Contrahuella vertical (Riser)
			_add_quad_direct(st_steps,
				Vector3(-half_w, y0, z0),
				Vector3(half_w, y0, z0),
				Vector3(half_w, y1 - bevel, z0),
				Vector3(-half_w, y1 - bevel, z0)
			)
			# Bisel frontal a 45°
			_add_quad_direct(st_steps,
				Vector3(-half_w, y1 - bevel, z0),
				Vector3(half_w, y1 - bevel, z0),
				Vector3(half_w, y1, z0 + bevel),
				Vector3(-half_w, y1, z0 + bevel)
			)
			# Huella horizontal (Tread)
			_add_quad_direct(st_steps,
				Vector3(-half_w, y1, z0 + bevel),
				Vector3(half_w, y1, z0 + bevel),
				Vector3(half_w, y1, z1),
				Vector3(-half_w, y1, z1)
			)
		else:
			# Huella horizontal descendente
			_add_quad_direct(st_steps,
				Vector3(-half_w, y1, z1),
				Vector3(half_w, y1, z1),
				Vector3(half_w, y1, z0 + bevel),
				Vector3(-half_w, y1, z0 + bevel)
			)
			# Bisel frontal descendente
			_add_quad_direct(st_steps,
				Vector3(-half_w, y1, z0 + bevel),
				Vector3(half_w, y1, z0 + bevel),
				Vector3(half_w, y1 + bevel, z0),
				Vector3(-half_w, y1 + bevel, z0)
			)
			# Contrahuella vertical descendente
			_add_quad_direct(st_steps,
				Vector3(-half_w, y1 + bevel, z0),
				Vector3(half_w, y1 + bevel, z0),
				Vector3(half_w, y0, z0),
				Vector3(-half_w, y0, z0)
			)

	# ==========================================================================
	# 3. PRETILES / ZANCAS LATERALES Y REMATE SUPERIOR (PANEL & TRIMS)
	# ==========================================================================
	var cap_bevel: float = 0.02
	var cap_thick: float = 0.06

	# Zanca izquierda (-X)
	_build_parapet_stringer(
		st_panel, st_trims,
		-half_tot_w, -half_w, start_z, end_z,
		y_top_trim, stair_rise, stringer_h,
		cap_bevel, cap_thick, is_downward, true
	)

	# Zanca derecha (+X)
	_build_parapet_stringer(
		st_panel, st_trims,
		half_w, half_tot_w, start_z, end_z,
		y_top_trim, stair_rise, stringer_h,
		cap_bevel, cap_thick, is_downward, false
	)

	# Pared trasera vertical entre zancas
	var back_top_y: float = -stair_rise if is_downward else stair_rise
	if not is_downward:
		_add_quad_direct(st_panel,
			Vector3(half_w, y_top_trim, end_z),
			Vector3(-half_w, y_top_trim, end_z),
			Vector3(-half_w, back_top_y, end_z),
			Vector3(half_w, back_top_y, end_z)
		)
	else:
		_add_quad_direct(st_panel,
			Vector3(half_w, back_top_y, end_z),
			Vector3(-half_w, back_top_y, end_z),
			Vector3(-half_w, y_top_trim, end_z),
			Vector3(half_w, y_top_trim, end_z)
		)

	# ==========================================================================
	# 4. LADRILLOS EN RELIEVE EN PAREDES LATERALES (BRICKS)
	# ==========================================================================
	if config.side_bricks_enabled:
		var rng := RandomNumberGenerator.new()
		rng.seed = config.seed

		var bw: float = 0.22
		var bh: float = 0.11
		var bz: float = 0.045

		var side_slots: Array[Vector2] = [
			Vector2(0.20, 0.45), # (z_ratio, y_ratio)
			Vector2(0.35, 0.35),
			Vector2(0.50, 0.65),
			Vector2(0.70, 0.55),
			Vector2(0.80, 0.25),
			Vector2(0.85, 0.75)
		]

		for side in [-1, 1]:
			var x_pos: float = (-half_tot_w - (bz * 0.5)) if side == -1 else (half_tot_w + (bz * 0.5))
			for slot in side_slots:
				if rng.randf() <= config.side_brick_density:
					var b_z: float = lerpf(start_z + 0.15, end_z - 0.15, slot.x) + rng.randf_range(-0.02, 0.02)
					var b_y: float = lerpf(y_top_trim + 0.10, (stair_rise + stringer_h) * 0.75, slot.y) + rng.randf_range(-0.02, 0.02)
					if is_downward:
						b_y = -b_y

					var t_brick := Transform3D(Basis(), Vector3(x_pos, b_y, b_z))
					_append_pillowed_brick(st_bricks, Vector3(bz, bh, bw), t_brick, 0.015)

	# ==========================================================================
	# 5. COMMIT DE SUPERFICIES Y MATERIALES PBR
	# ==========================================================================
	var mesh := ArrayMesh.new()

	st_steps.generate_tangents()
	mesh = st_steps.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "StairSteps")

	st_trims.generate_tangents()
	mesh = st_trims.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "Trims")

	st_panel.generate_tangents()
	mesh = st_panel.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "WallPanel")

	var brick_arrays = st_bricks.commit_to_arrays()
	if brick_arrays.size() > 0 and brick_arrays[Mesh.ARRAY_VERTEX] != null and brick_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, brick_arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "Bricks")

	g_mesh.mesh = mesh
	var min_y: float = -stair_rise if is_downward else 0.0
	var max_y: float = 0.0 if is_downward else stair_rise + stringer_h
	g_mesh.bounds = AABB(Vector3(-half_tot_w - overhang, min_y, start_z), Vector3((half_tot_w + overhang) * 2.0, max_y - min_y, total_depth))

	# Aplicar Materiales PBR
	g_mesh.material_slots[0] = _WallMaterialFactoryScript.create_floor_slab_material()
	g_mesh.material_slots[1] = _WallMaterialFactoryScript.create_trim_material()
	g_mesh.material_slots[2] = _WallMaterialFactoryScript.create_panel_material()
	if mesh.get_surface_count() > 3:
		g_mesh.material_slots[3] = _WallMaterialFactoryScript.create_brick_material()

	# ==========================================================================
	# 6. COLISIONES FÍSICAS COMPUESTAS
	# ==========================================================================
	for i in range(num_steps):
		var y_mid_col: float = (float(i) + 0.5) * step_height
		var z_mid_col: float = start_z + ((float(i) + 0.5) * step_depth)
		if is_downward:
			y_mid_col = -y_mid_col

		var col_step := BoxShape3D.new()
		col_step.size = Vector3(step_w, step_height, step_depth)
		g_mesh.add_collision_shape(col_step, Transform3D(Basis(), Vector3(0.0, y_mid_col, z_mid_col)))

	# Colisión Zanca Izquierda
	var col_left := BoxShape3D.new()
	col_left.size = Vector3(stringer_w, stair_rise + stringer_h, total_depth)
	g_mesh.add_collision_shape(col_left, Transform3D(Basis(), Vector3(-half_w - (stringer_w * 0.5), (stair_rise + stringer_h) * 0.5 * (-1.0 if is_downward else 1.0), 0.0)))

	# Colisión Zanca Derecha
	var col_right := BoxShape3D.new()
	col_right.size = Vector3(stringer_w, stair_rise + stringer_h, total_depth)
	g_mesh.add_collision_shape(col_right, Transform3D(Basis(), Vector3(half_w + (stringer_w * 0.5), (stair_rise + stringer_h) * 0.5 * (-1.0 if is_downward else 1.0), 0.0)))

	return g_mesh

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS AUXILIARES
# ==============================================================================

static func _build_side_bottom_trim(
	st: SurfaceTool, x_out: float, x_mid_chamfer: float, _x_in: float,
	z_start: float, z_end: float, y_bot: float, y_mid: float, y_top: float,
	side_dir: float
) -> void:
	if side_dir < 0.0:
		# Cara vertical exterior
		_add_quad_direct(st, Vector3(x_out, y_bot, z_end), Vector3(x_out, y_bot, z_start), Vector3(x_out, y_mid, z_start), Vector3(x_out, y_mid, z_end))
		# Bisel a 45° hacia adentro
		_add_quad_direct(st, Vector3(x_out, y_mid, z_end), Vector3(x_out, y_mid, z_start), Vector3(x_mid_chamfer, y_top, z_start), Vector3(x_mid_chamfer, y_top, z_end))
	else:
		# Cara vertical exterior derecha
		_add_quad_direct(st, Vector3(x_out, y_bot, z_start), Vector3(x_out, y_bot, z_end), Vector3(x_out, y_mid, z_end), Vector3(x_out, y_mid, z_start))
		# Bisel a 45° hacia adentro derecha
		_add_quad_direct(st, Vector3(x_out, y_mid, z_start), Vector3(x_out, y_mid, z_end), Vector3(x_mid_chamfer, y_top, z_end), Vector3(x_mid_chamfer, y_top, z_start))

static func _build_parapet_stringer(
	st_panel: SurfaceTool, st_trims: SurfaceTool,
	x_min: float, x_max: float, z_start: float, z_end: float,
	y_base: float, stair_rise: float, parapet_h: float,
	cap_bevel: float, _cap_thick: float, is_downward: bool, is_left: bool
) -> void:
	var y_front_top: float = y_base + parapet_h
	var y_back_top: float = (stair_rise if not is_downward else -stair_rise) + parapet_h

	var v_bot_start := Vector3(x_min if is_left else x_max, y_base, z_start)
	var v_bot_end := Vector3(x_min if is_left else x_max, y_base, z_end)
	var v_top_start := Vector3(x_min if is_left else x_max, y_front_top, z_start)
	var v_top_end := Vector3(x_min if is_left else x_max, y_back_top, z_end)

	var vi_bot_start := Vector3(x_max if is_left else x_min, y_base, z_start)
	var vi_bot_end := Vector3(x_max if is_left else x_min, y_base, z_end)
	var vi_top_start := Vector3(x_max if is_left else x_min, y_front_top, z_start)
	var vi_top_end := Vector3(x_max if is_left else x_min, y_back_top, z_end)

	# 1. Panel Lateral Exterior
	if is_left:
		_add_quad_direct(st_panel, v_bot_end, v_bot_start, v_top_start, v_top_end)
		_add_quad_direct(st_panel, vi_bot_start, vi_bot_end, vi_top_end, vi_top_start)
	else:
		_add_quad_direct(st_panel, v_bot_start, v_bot_end, v_top_end, v_top_start)
		_add_quad_direct(st_panel, vi_bot_end, vi_bot_start, vi_top_start, vi_top_end)

	# 2. Tapas Frontal y Trasera de la Zanca
	if is_left:
		_add_quad_direct(st_panel, v_bot_start, vi_bot_start, vi_top_start, v_top_start)
		_add_quad_direct(st_panel, vi_bot_end, v_bot_end, v_top_end, vi_top_end)
	else:
		_add_quad_direct(st_panel, vi_bot_start, v_bot_start, v_top_start, vi_top_start)
		_add_quad_direct(st_panel, v_bot_end, vi_bot_end, vi_top_end, v_top_end)

	# 3. Remate Superior / Pasamanos con Bisel a 45° (TRIMS)
	var b := cap_bevel
	var p_out_start := Vector3(x_min + b if is_left else x_max - b, y_front_top, z_start)
	var p_out_end := Vector3(x_min + b if is_left else x_max - b, y_back_top, z_end)
	var p_in_start := Vector3(x_max - b if is_left else x_min + b, y_front_top, z_start)
	var p_in_end := Vector3(x_max - b if is_left else x_min + b, y_back_top, z_end)

	if is_left:
		_add_quad_direct(st_trims, p_out_start, p_in_start, p_in_end, p_out_end)
		_add_quad_direct(st_trims, v_top_start, p_out_start, p_out_end, v_top_end)
		_add_quad_direct(st_trims, p_in_start, vi_top_start, vi_top_end, p_in_end)
	else:
		_add_quad_direct(st_trims, p_in_start, p_out_start, p_out_end, p_in_end)
		_add_quad_direct(st_trims, p_out_start, v_top_start, v_top_end, p_out_end)
		_add_quad_direct(st_trims, vi_top_start, p_in_start, p_in_end, vi_top_end)

static func _append_pillowed_brick(st: SurfaceTool, size: Vector3, transform: Transform3D, bevel: float = 0.028) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var b: float = clampf(bevel, 0.001, minf(hx, minf(hy, hz)) * 0.45)
	var ix: float = hx - b
	var iy: float = hy - b
	var iz: float = hz - b

	_add_quad_direct_xform(st, transform, Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz), Vector3(ix, iy, hz), Vector3(-ix, iy, hz))
	_add_quad_direct_xform(st, transform, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz))
	_add_quad_direct_xform(st, transform, Vector3(hx, -iy, iz), Vector3(hx, -iy, -iz), Vector3(hx, iy, -iz), Vector3(hx, iy, iz))
	_add_quad_direct_xform(st, transform, Vector3(-hx, -iy, -iz), Vector3(-hx, -iy, iz), Vector3(-hx, iy, iz), Vector3(-hx, iy, -iz))
	_add_quad_direct_xform(st, transform, Vector3(-ix, hy, iz), Vector3(ix, hy, iz), Vector3(ix, hy, -iz), Vector3(-ix, hy, -iz))
	_add_quad_direct_xform(st, transform, Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz), Vector3(ix, -hy, iz), Vector3(-ix, -hy, iz))

	_add_quad_direct_xform(st, transform, Vector3(-ix, iy, hz), Vector3(ix, iy, hz), Vector3(ix, hy, iz), Vector3(-ix, hy, iz))
	_add_quad_direct_xform(st, transform, Vector3(-ix, -hy, iz), Vector3(ix, -hy, iz), Vector3(ix, -iy, hz), Vector3(-ix, -iy, hz))
	_add_quad_direct_xform(st, transform, Vector3(-ix, hy, -iz), Vector3(ix, hy, -iz), Vector3(ix, iy, -hz), Vector3(-ix, iy, -hz))
	_add_quad_direct_xform(st, transform, Vector3(ix, -hy, -iz), Vector3(-ix, -hy, -iz), Vector3(-ix, -iy, -hz), Vector3(ix, -iy, -hz))

	_add_quad_direct_xform(st, transform, Vector3(ix, -iy, hz), Vector3(hx, -iy, iz), Vector3(hx, iy, iz), Vector3(ix, iy, hz))
	_add_quad_direct_xform(st, transform, Vector3(-hx, -iy, iz), Vector3(-ix, -iy, hz), Vector3(-ix, iy, hz), Vector3(-hx, iy, iz))
	_add_quad_direct_xform(st, transform, Vector3(hx, -iy, -iz), Vector3(ix, -iy, -hz), Vector3(ix, iy, -hz), Vector3(hx, iy, -iz))
	_add_quad_direct_xform(st, transform, Vector3(-ix, -iy, -hz), Vector3(-hx, -iy, -iz), Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz))

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

static func _add_quad_direct_xform(st: SurfaceTool, xform: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle_direct(st, xform * p0, xform * p1, xform * p2)
	_add_triangle_direct(st, xform * p0, xform * p2, xform * p3)
