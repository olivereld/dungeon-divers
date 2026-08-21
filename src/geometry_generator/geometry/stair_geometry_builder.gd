class_name StairGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de alta fidelidad para escaleras góticas estilizadas (Fase M2).
## Soporta:
## 1. Escaleras Ascendentes (UP): Estructura monumental sobre el suelo con zócalo, zancas elevadas y remates.
## 2. Fosos de Descenso (DOWN): Hueco excavado en el suelo con brocal perimetral sutil a nivel Y = 0.0 y peldaños bajando al nivel inferior.

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

	var bevel: float = config.step_bevel

	if not is_downward:
		# ======================================================================
		# ESCALERA ASCENDENTE (UP): Estructura sobre el suelo (Y >= 0.0)
		# ======================================================================
		var h_main: float = bot_trim_h - bot_slope_h
		var y_bot: float = 0.0
		var y_mid: float = y_bot + h_main
		var y_top_trim: float = y_bot + bot_trim_h

		# 1. Zócalo perimetral
		_build_side_bottom_trim(st_trims, -half_tot_w - overhang, -half_tot_w, -half_w, start_z, end_z, y_bot, y_mid, y_top_trim, -1.0)
		_build_side_bottom_trim(st_trims, half_tot_w, half_tot_w + overhang, half_w, start_z, end_z, y_bot, y_mid, y_top_trim, 1.0)

		_add_quad_direct(st_trims, Vector3(-half_tot_w - overhang, y_bot, start_z), Vector3(-half_w, y_bot, start_z), Vector3(-half_w, y_mid, start_z), Vector3(-half_tot_w - overhang, y_mid, start_z))
		_add_quad_direct(st_trims, Vector3(-half_tot_w - overhang, y_mid, start_z), Vector3(-half_w, y_mid, start_z), Vector3(-half_w, y_top_trim, start_z), Vector3(-half_tot_w, y_top_trim, start_z))

		_add_quad_direct(st_trims, Vector3(half_w, y_bot, start_z), Vector3(half_tot_w + overhang, y_bot, start_z), Vector3(half_tot_w + overhang, y_mid, start_z), Vector3(half_w, y_mid, start_z))
		_add_quad_direct(st_trims, Vector3(half_w, y_mid, start_z), Vector3(half_tot_w + overhang, y_mid, start_z), Vector3(half_tot_w, y_top_trim, start_z), Vector3(half_w, y_top_trim, start_z))

		_add_quad_direct(st_trims, Vector3(half_tot_w + overhang, y_bot, end_z), Vector3(-half_tot_w - overhang, y_bot, end_z), Vector3(-half_tot_w - overhang, y_mid, end_z), Vector3(half_tot_w + overhang, y_mid, end_z))
		_add_quad_direct(st_trims, Vector3(half_tot_w + overhang, y_mid, end_z), Vector3(-half_tot_w - overhang, y_mid, end_z), Vector3(-half_tot_w, y_top_trim, end_z), Vector3(half_tot_w, y_top_trim, end_z))

		# 2. Peldaños ascendentes
		for i in range(num_steps):
			var y0: float = float(i) * step_height
			var y1: float = float(i + 1) * step_height
			var z0: float = start_z + (float(i) * step_depth)
			var z1: float = start_z + (float(i + 1) * step_depth)

			_add_quad_direct(st_steps, Vector3(-half_w, y0, z0), Vector3(half_w, y0, z0), Vector3(half_w, y1 - bevel, z0), Vector3(-half_w, y1 - bevel, z0))
			_add_quad_direct(st_steps, Vector3(-half_w, y1 - bevel, z0), Vector3(half_w, y1 - bevel, z0), Vector3(half_w, y1, z0 + bevel), Vector3(-half_w, y1, z0 + bevel))
			_add_quad_direct(st_steps, Vector3(-half_w, y1, z0 + bevel), Vector3(half_w, y1, z0 + bevel), Vector3(half_w, y1, z1), Vector3(-half_w, y1, z1))

		# 3. Zancas laterales inclinadas
		var cap_bevel: float = 0.02
		_build_parapet_stringer_up(st_panel, st_trims, -half_tot_w, -half_w, start_z, end_z, y_top_trim, stair_rise, stringer_h, cap_bevel, true)
		_build_parapet_stringer_up(st_panel, st_trims, half_w, half_tot_w, start_z, end_z, y_top_trim, stair_rise, stringer_h, cap_bevel, false)

		# Pared trasera
		_add_quad_direct(st_panel, Vector3(half_w, y_top_trim, end_z), Vector3(-half_w, y_top_trim, end_z), Vector3(-half_w, stair_rise, end_z), Vector3(half_w, stair_rise, end_z))

		# 4. Ladrillos en relieve laterales (calculados dentro de la rampa triangular real)
		if config.side_bricks_enabled:
			var rng := RandomNumberGenerator.new()
			rng.seed = config.seed
			var bw: float = 0.22; var bh: float = 0.11; var bz: float = 0.045
			var side_slots: Array[Vector2] = [
				Vector2(0.20, 0.35),
				Vector2(0.40, 0.40),
				Vector2(0.60, 0.55),
				Vector2(0.75, 0.30),
				Vector2(0.85, 0.70)
			]
			for side in [-1, 1]:
				var x_pos: float = (-half_tot_w - (bz * 0.5)) if side == -1 else (half_tot_w + (bz * 0.5))
				for slot in side_slots:
					if rng.randf() <= config.side_brick_density:
						var b_z: float = lerpf(start_z + 0.20, end_z - 0.20, slot.x) + rng.randf_range(-0.02, 0.02)
						var t_z: float = clampf((b_z - start_z) / total_depth, 0.0, 1.0)
						var ramp_top_y: float = lerpf(y_top_trim + stringer_h, stair_rise + stringer_h, t_z)
						var ramp_bot_y: float = y_top_trim

						var safe_max_y: float = ramp_top_y - (bh * 0.5 + 0.10)
						var safe_min_y: float = ramp_bot_y + (bh * 0.5 + 0.05)

						if safe_max_y > safe_min_y:
							var b_y: float = lerpf(safe_min_y, safe_max_y, slot.y)
							var t_brick := Transform3D(Basis(), Vector3(x_pos, b_y, b_z))
							_append_pillowed_brick(st_bricks, Vector3(bz, bh, bw), t_brick, 0.015)

		# Colisiones UP
		for i in range(num_steps):
			var y_mid_col: float = (float(i) + 0.5) * step_height
			var z_mid_col: float = start_z + ((float(i) + 0.5) * step_depth)
			var col_step := BoxShape3D.new()
			col_step.size = Vector3(step_w, step_height, step_depth)
			g_mesh.add_collision_shape(col_step, Transform3D(Basis(), Vector3(0.0, y_mid_col, z_mid_col)))

		var col_h: float = stair_rise + stringer_h
		var col_y: float = col_h * 0.5
		var col_left := BoxShape3D.new()
		col_left.size = Vector3(stringer_w, col_h, total_depth)
		g_mesh.add_collision_shape(col_left, Transform3D(Basis(), Vector3(-half_w - (stringer_w * 0.5), col_y, 0.0)))
		var col_right := BoxShape3D.new()
		col_right.size = Vector3(stringer_w, col_h, total_depth)
		g_mesh.add_collision_shape(col_right, Transform3D(Basis(), Vector3(half_w + (stringer_w * 0.5), col_y, 0.0)))

	else:
		# ======================================================================
		# FOSO DE DESCENSO (DOWN): Hueco en el suelo con peldaños hacia Y <= 0.0
		# ======================================================================
		var curb_h: float = 0.06 # Altura sutil del brocal de piedra que enmarca el hueco en el suelo
		var curb_bevel: float = 0.02

		# 1. Brocal perimetral del hueco a nivel de suelo (Trims a Y = 0.0 .. curb_h)
		# Lado izquierdo (-X)
		_build_curb_strip(st_trims, -half_tot_w, -half_w, start_z, end_z, curb_h, curb_bevel, true)
		# Lado derecho (+X)
		_build_curb_strip(st_trims, half_w, half_tot_w, start_z, end_z, curb_h, curb_bevel, false)
		# Lado posterior (+Z)
		_build_curb_back(st_trims, -half_tot_w, half_tot_w, end_z - stringer_w, end_z, curb_h, curb_bevel)

		# 2. Paredes interiores del foso de piedra (WallPanel que forra el hueco)
		# Pared interior izquierda
		_add_quad_direct(st_panel, Vector3(-half_w, curb_h, start_z), Vector3(-half_w, curb_h, end_z), Vector3(-half_w, -stair_rise, end_z), Vector3(-half_w, 0.0, start_z))
		# Pared interior derecha
		_add_quad_direct(st_panel, Vector3(half_w, curb_h, end_z), Vector3(half_w, curb_h, start_z), Vector3(half_w, 0.0, start_z), Vector3(half_w, -stair_rise, end_z))
		# Pared interior de fondo
		_add_quad_direct(st_panel, Vector3(half_w, curb_h, end_z), Vector3(-half_w, curb_h, end_z), Vector3(-half_w, -stair_rise, end_z), Vector3(half_w, -stair_rise, end_z))

		# 3. Peldaños descendentes
		for i in range(num_steps):
			var y_top_step: float = -float(i) * step_height
			var y_bot_step: float = -float(i + 1) * step_height
			var z0: float = start_z + (float(i) * step_depth)
			var z1: float = start_z + (float(i + 1) * step_depth)

			# Contrahuella vertical hacia abajo
			_add_quad_direct(st_steps,
				Vector3(-half_w, y_top_step, z0),
				Vector3(half_w, y_top_step, z0),
				Vector3(half_w, y_bot_step + bevel, z0),
				Vector3(-half_w, y_bot_step + bevel, z0)
			)
			# Bisel frontal a 45°
			_add_quad_direct(st_steps,
				Vector3(-half_w, y_bot_step + bevel, z0),
				Vector3(half_w, y_bot_step + bevel, z0),
				Vector3(half_w, y_bot_step, z0 + bevel),
				Vector3(-half_w, y_bot_step, z0 + bevel)
			)
			# Huella horizontal descendente
			_add_quad_direct(st_steps,
				Vector3(-half_w, y_bot_step, z0 + bevel),
				Vector3(half_w, y_bot_step, z0 + bevel),
				Vector3(half_w, y_bot_step, z1),
				Vector3(-half_w, y_bot_step, z1)
			)

		# 4. Ladrillos interiores de mampostería en las paredes del foso
		if config.side_bricks_enabled:
			var rng := RandomNumberGenerator.new()
			rng.seed = config.seed
			var bw: float = 0.20; var bh: float = 0.10; var bz: float = 0.035
			var side_slots: Array[Vector2] = [Vector2(0.25, 0.4), Vector2(0.50, 0.5), Vector2(0.75, 0.4), Vector2(0.85, 0.6)]
			for side in [-1, 1]:
				var x_pos: float = (-half_w + (bz * 0.5)) if side == -1 else (half_w - (bz * 0.5))
				for slot in side_slots:
					if rng.randf() <= config.side_brick_density:
						var b_z: float = lerpf(start_z + 0.20, end_z - 0.20, slot.x)
						var t_z: float = clampf((b_z - start_z) / total_depth, 0.0, 1.0)
						var step_y: float = -t_z * stair_rise
						var safe_min_y: float = step_y + (bh * 0.5 + 0.08)
						var safe_max_y: float = -(bh * 0.5 + 0.04)

						if safe_max_y > safe_min_y:
							var b_y: float = lerpf(safe_min_y, safe_max_y, slot.y)
							var t_brick := Transform3D(Basis(), Vector3(x_pos, b_y, b_z))
							_append_pillowed_brick(st_bricks, Vector3(bz, bh, bw), t_brick, 0.012)

		# Colisiones DOWN (Cajas escalonadas hacia abajo + caja base inferior)
		for i in range(num_steps):
			var y_mid_col: float = -((float(i) + 0.5) * step_height)
			var z_mid_col: float = start_z + ((float(i) + 0.5) * step_depth)
			var col_step := BoxShape3D.new()
			col_step.size = Vector3(step_w, step_height, step_depth)
			g_mesh.add_collision_shape(col_step, Transform3D(Basis(), Vector3(0.0, y_mid_col, z_mid_col)))

		var col_shaft_left := BoxShape3D.new()
		col_shaft_left.size = Vector3(stringer_w, stair_rise + curb_h, total_depth)
		g_mesh.add_collision_shape(col_shaft_left, Transform3D(Basis(), Vector3(-half_w - (stringer_w * 0.5), (-stair_rise + curb_h) * 0.5, 0.0)))

		var col_shaft_right := BoxShape3D.new()
		col_shaft_right.size = Vector3(stringer_w, stair_rise + curb_h, total_depth)
		g_mesh.add_collision_shape(col_shaft_right, Transform3D(Basis(), Vector3(half_w + (stringer_w * 0.5), (-stair_rise + curb_h) * 0.5, 0.0)))

	# ==========================================================================
	# COMMIT DE SUPERFICIES Y MATERIALES PBR
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
	var max_y: float = 0.06 if is_downward else (stair_rise + stringer_h)
	g_mesh.bounds = AABB(Vector3(-half_tot_w - overhang, min_y, start_z), Vector3((half_tot_w + overhang) * 2.0, max_y - min_y, total_depth))

	# Materiales PBR
	g_mesh.material_slots[0] = _WallMaterialFactoryScript.create_floor_slab_material()
	g_mesh.material_slots[1] = _WallMaterialFactoryScript.create_trim_material()
	g_mesh.material_slots[2] = _WallMaterialFactoryScript.create_panel_material()
	if mesh.get_surface_count() > 3:
		g_mesh.material_slots[3] = _WallMaterialFactoryScript.create_brick_material()

	return g_mesh

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS AUXILIARES
# ==============================================================================

static func _build_curb_strip(st: SurfaceTool, x_min: float, x_max: float, z_start: float, z_end: float, curb_h: float, bevel: float, is_left: bool) -> void:
	var b: float = bevel
	var y0: float = 0.0
	var y1: float = curb_h

	# Tapa superior con bisel
	_add_quad_direct(st, Vector3(x_min, y1, z_start), Vector3(x_max, y1, z_start), Vector3(x_max, y1, z_end), Vector3(x_min, y1, z_end))
	# Bisel exterior
	if is_left:
		_add_quad_direct(st, Vector3(x_min, y0, z_end), Vector3(x_min, y0, z_start), Vector3(x_min + b, y1, z_start), Vector3(x_min + b, y1, z_end))
	else:
		_add_quad_direct(st, Vector3(x_max, y0, z_start), Vector3(x_max, y0, z_end), Vector3(x_max - b, y1, z_end), Vector3(x_max - b, y1, z_start))

static func _build_curb_back(st: SurfaceTool, x_min: float, x_max: float, z_start: float, z_end: float, curb_h: float, bevel: float) -> void:
	var b: float = bevel
	_add_quad_direct(st, Vector3(x_min, curb_h, z_start), Vector3(x_max, curb_h, z_start), Vector3(x_max, curb_h, z_end), Vector3(x_min, curb_h, z_end))
	_add_quad_direct(st, Vector3(x_max, 0.0, z_end), Vector3(x_min, 0.0, z_end), Vector3(x_min, curb_h, z_end - b), Vector3(x_max, curb_h, z_end - b))

static func _build_side_bottom_trim(
	st: SurfaceTool, x_out: float, x_mid_chamfer: float, _x_in: float,
	z_start: float, z_end: float, y_bot: float, y_mid: float, y_top: float,
	side_dir: float
) -> void:
	if side_dir < 0.0:
		_add_quad_direct(st, Vector3(x_out, y_bot, z_end), Vector3(x_out, y_bot, z_start), Vector3(x_out, y_mid, z_start), Vector3(x_out, y_mid, z_end))
		_add_quad_direct(st, Vector3(x_out, y_mid, z_end), Vector3(x_out, y_mid, z_start), Vector3(x_mid_chamfer, y_top, z_start), Vector3(x_mid_chamfer, y_top, z_end))
	else:
		_add_quad_direct(st, Vector3(x_out, y_bot, z_start), Vector3(x_out, y_bot, z_end), Vector3(x_out, y_mid, z_end), Vector3(x_out, y_mid, z_start))
		_add_quad_direct(st, Vector3(x_out, y_mid, z_start), Vector3(x_out, y_mid, z_end), Vector3(x_mid_chamfer, y_top, z_end), Vector3(x_mid_chamfer, y_top, z_start))

static func _build_parapet_stringer_up(
	st_panel: SurfaceTool, st_trims: SurfaceTool,
	x_min: float, x_max: float, z_start: float, z_end: float,
	y_base: float, stair_rise: float, parapet_h: float,
	cap_bevel: float, is_left: bool
) -> void:
	var y_front_top: float = y_base + parapet_h
	var y_back_top: float = stair_rise + parapet_h

	var v_bot_start := Vector3(x_min if is_left else x_max, y_base, z_start)
	var v_bot_end := Vector3(x_min if is_left else x_max, y_base, z_end)
	var v_top_start := Vector3(x_min if is_left else x_max, y_front_top, z_start)
	var v_top_end := Vector3(x_min if is_left else x_max, y_back_top, z_end)

	var vi_bot_start := Vector3(x_max if is_left else x_min, y_base, z_start)
	var vi_bot_end := Vector3(x_max if is_left else x_min, y_base, z_end)
	var vi_top_start := Vector3(x_max if is_left else x_min, y_front_top, z_start)
	var vi_top_end := Vector3(x_max if is_left else x_min, y_back_top, z_end)

	if is_left:
		_add_quad_direct(st_panel, v_bot_end, v_bot_start, v_top_start, v_top_end)
		_add_quad_direct(st_panel, vi_bot_start, vi_bot_end, vi_top_end, vi_top_start)
		_add_quad_direct(st_panel, v_bot_start, vi_bot_start, vi_top_start, v_top_start)
		_add_quad_direct(st_panel, vi_bot_end, v_bot_end, v_top_end, vi_top_end)
	else:
		_add_quad_direct(st_panel, v_bot_start, v_bot_end, v_top_end, v_top_start)
		_add_quad_direct(st_panel, vi_bot_end, vi_bot_start, vi_top_start, vi_top_end)
		_add_quad_direct(st_panel, vi_bot_start, v_bot_start, v_top_start, vi_top_start)
		_add_quad_direct(st_panel, v_bot_end, vi_bot_end, vi_top_end, v_top_end)

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
	var hx: float = size.x * 0.5; var hy: float = size.y * 0.5; var hz: float = size.z * 0.5
	var b: float = clampf(bevel, 0.001, minf(hx, minf(hy, hz)) * 0.45)
	var ix: float = hx - b; var iy: float = hy - b; var iz: float = hz - b

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
