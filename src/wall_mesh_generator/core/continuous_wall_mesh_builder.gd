class_name ContinuousWallMeshBuilder
extends RefCounted

## Ensamblador de malla continua fluida para la estructura de paredes de la mazmorra.
## Extruye bucles poligonales continuos cerrados con uniones en inglete (miter joints) a 45°,
## eliminando completamente cruces, solapamientos y cortes entre piezas.

const _ContinuousWallExtractorScript = preload("res://src/wall_mesh_generator/core/continuous_wall_extractor.gd")
const _BrickGeometryBuilderScript = preload("res://src/wall_mesh_generator/core/brick_geometry_builder.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")

## Construye la malla continua unificada de paredes para todo el CellGrid.
func build_dungeon_wall_mesh(
	grid: CellGrid,
	config: WallMeshConfig = null,
	material_preset: int = 0
) -> ArrayMesh:
	if grid == null:
		return ArrayMesh.new()

	if config == null:
		config = _WallMeshConfigScript.new()

	var loops: Array = _ContinuousWallExtractorScript.extract_wall_loops(grid, config.cube_size)
	if loops.is_empty():
		return ArrayMesh.new()

	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()
	var st_bricks := SurfaceTool.new()

	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_h: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()
	var bot_trim_h: float = config.bottom_trim_height
	var top_trim_h: float = config.top_trim_height

	var bot_slope_h: float = config.bottom_trim_slope_height
	var top_slope_h: float = config.top_trim_slope_height

	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	for loop_idx in range(loops.size()):
		var loop = loops[loop_idx]
		var pts: Array[Vector3] = loop.vertices
		var n: int = pts.size()
		if n < 3:
			continue

		# 1. Calcular vectores miter en cada vértice del bucle
		var miter_dirs: Array[Vector3] = []
		var normals_in: Array[Vector3] = [] # Normales hacia la habitación

		for i in range(n):
			var prev_pt: Vector3 = pts[(i - 1 + n) % n]
			var curr_pt: Vector3 = pts[i]
			var next_pt: Vector3 = pts[(i + 1) % n]

			var t_in: Vector3 = (curr_pt - prev_pt).normalized()
			var t_out: Vector3 = (next_pt - curr_pt).normalized()

			# Normal perpendicular exterior (hacia el sólido del muro, hacia la derecha del avance)
			var n_wall_in := Vector3(t_in.z, 0.0, -t_in.x)
			var n_wall_out := Vector3(t_out.z, 0.0, -t_out.x)

			var miter: Vector3 = (n_wall_in + n_wall_out)
			if miter.length_squared() < 0.001:
				miter = n_wall_in
			miter_dirs.append(miter)
			normals_in.append(-n_wall_in)

		# 2. Extruir cada arista del bucle como una cinta continua con uniones en inglete
		for i in range(n):
			var next_i: int = (i + 1) % n
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[next_i]

			var m0: Vector3 = miter_dirs[i]
			var m1: Vector3 = miter_dirs[next_i]

			# Vértices base sobre la línea de contorno
			var p0_inner_thick: Vector3 = p0 - (m0 * (d * 0.5))
			var p1_inner_thick: Vector3 = p1 - (m1 * (d * 0.5))

			var p0_inner_thin: Vector3 = p0
			var p1_inner_thin: Vector3 = p1

			var p0_outer_thick: Vector3 = p0 + (m0 * (w_thick - d * 0.5))
			var p1_outer_thick: Vector3 = p1 + (m1 * (w_thick - d * 0.5))

			var p0_outer_thin: Vector3 = p0 + (m0 * w_thin)
			var p1_outer_thin: Vector3 = p1 + (m1 * w_thin)

			# --- 2.1 ZÓCALO INFERIOR (TRIMS) ---
			var y_bot_base: float = 0.0
			var y_mid_base: float = bot_trim_h - bot_slope_h
			var y_top_base: float = bot_trim_h

			# Cara frontal vertical inferior
			_add_quad(st_trims,
				Vector3(p0_inner_thick.x, y_bot_base, p0_inner_thick.z),
				Vector3(p1_inner_thick.x, y_bot_base, p1_inner_thick.z),
				Vector3(p1_inner_thick.x, y_mid_base, p1_inner_thick.z),
				Vector3(p0_inner_thick.x, y_mid_base, p0_inner_thick.z)
			)
			# Pendiente frontal a 45° superior
			_add_quad(st_trims,
				Vector3(p0_inner_thick.x, y_mid_base, p0_inner_thick.z),
				Vector3(p1_inner_thick.x, y_mid_base, p1_inner_thick.z),
				Vector3(p1_inner_thin.x, y_top_base, p1_inner_thin.z),
				Vector3(p0_inner_thin.x, y_top_base, p0_inner_thin.z)
			)
			# Cara trasera exterior zócalo
			_add_quad(st_trims,
				Vector3(p1_outer_thick.x, y_bot_base, p1_outer_thick.z),
				Vector3(p0_outer_thick.x, y_bot_base, p0_outer_thick.z),
				Vector3(p0_outer_thick.x, y_mid_base, p0_outer_thick.z),
				Vector3(p1_outer_thick.x, y_mid_base, p1_outer_thick.z)
			)
			# Pendiente trasera exterior a 45°
			_add_quad(st_trims,
				Vector3(p1_outer_thick.x, y_mid_base, p1_outer_thick.z),
				Vector3(p0_outer_thick.x, y_mid_base, p0_outer_thick.z),
				Vector3(p0_outer_thin.x, y_top_base, p0_outer_thin.z),
				Vector3(p1_outer_thin.x, y_top_base, p1_outer_thin.z)
			)

			# --- 2.2 PANEL CENTRAL DE PARED (WALLPANEL) ---
			var y_bot_panel: float = bot_trim_h
			var y_top_panel: float = total_h - top_trim_h

			# Cara frontal del panel de pared
			_add_quad(st_panel,
				Vector3(p0_inner_thin.x, y_bot_panel, p0_inner_thin.z),
				Vector3(p1_inner_thin.x, y_bot_panel, p1_inner_thin.z),
				Vector3(p1_inner_thin.x, y_top_panel, p1_inner_thin.z),
				Vector3(p0_inner_thin.x, y_top_panel, p0_inner_thin.z)
			)
			# Cara trasera del panel de pared
			_add_quad(st_panel,
				Vector3(p1_outer_thin.x, y_bot_panel, p1_outer_thin.z),
				Vector3(p0_outer_thin.x, y_bot_panel, p0_outer_thin.z),
				Vector3(p0_outer_thin.x, y_top_panel, p0_outer_thin.z),
				Vector3(p1_outer_thin.x, y_top_panel, p1_outer_thin.z)
			)

			# --- 2.3 CORNISA SUPERIOR (TRIMS) ---
			var y_bot_cornice: float = total_h - top_trim_h
			var y_mid_cornice: float = total_h - top_trim_h + top_slope_h
			var y_top_cornice: float = total_h

			# Pendiente frontal inferior a 45°
			_add_quad(st_trims,
				Vector3(p0_inner_thin.x, y_bot_cornice, p0_inner_thin.z),
				Vector3(p1_inner_thin.x, y_bot_cornice, p1_inner_thin.z),
				Vector3(p1_inner_thick.x, y_mid_cornice, p1_inner_thick.z),
				Vector3(p0_inner_thick.x, y_mid_cornice, p0_inner_thick.z)
			)
			# Cara frontal vertical superior
			_add_quad(st_trims,
				Vector3(p0_inner_thick.x, y_mid_cornice, p0_inner_thick.z),
				Vector3(p1_inner_thick.x, y_mid_cornice, p1_inner_thick.z),
				Vector3(p1_inner_thick.x, y_top_cornice, p1_inner_thick.z),
				Vector3(p0_inner_thick.x, y_top_cornice, p0_inner_thick.z)
			)
			# Tapa superior plana de la cornisa
			_add_quad(st_trims,
				Vector3(p0_inner_thick.x, y_top_cornice, p0_inner_thick.z),
				Vector3(p1_inner_thick.x, y_top_cornice, p1_inner_thick.z),
				Vector3(p1_outer_thick.x, y_top_cornice, p1_outer_thick.z),
				Vector3(p0_outer_thick.x, y_top_cornice, p0_outer_thick.z)
			)
			# Cara trasera vertical superior
			_add_quad(st_trims,
				Vector3(p1_outer_thick.x, y_mid_cornice, p1_outer_thick.z),
				Vector3(p0_outer_thick.x, y_mid_cornice, p0_outer_thick.z),
				Vector3(p0_outer_thick.x, y_top_cornice, p0_outer_thick.z),
				Vector3(p1_outer_thick.x, y_top_cornice, p1_outer_thick.z)
			)
			# Pendiente trasera inferior a 45°
			_add_quad(st_trims,
				Vector3(p1_outer_thin.x, y_bot_cornice, p1_outer_thin.z),
				Vector3(p0_outer_thin.x, y_bot_cornice, p0_outer_thin.z),
				Vector3(p0_outer_thick.x, y_mid_cornice, p0_outer_thick.z),
				Vector3(p1_outer_thick.x, y_mid_cornice, p1_outer_thick.z)
			)

			# --- 2.4 DISTRIBUCIÓN DE LADRILLOS A LO LARGO DEL TRAMO ---
			var edge_vec: Vector3 = p1 - p0
			var edge_len: float = edge_vec.length()
			var edge_tan: Vector3 = edge_vec.normalized()
			var edge_norm: Vector3 = Vector3(-edge_tan.z, 0.0, edge_tan.x) # Hacia la habitación

			_distribute_bricks_on_edge(st_bricks, p0, p1, edge_len, edge_tan, edge_norm, config, rng, panel_h, bot_trim_h)

	var mesh := ArrayMesh.new()

	# Superficie 0: Trims (Cornisas y Zócalos)
	st_trims.generate_tangents()
	mesh = st_trims.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_name(0, "Trims")
		var trim_mat = _WallMaterialFactoryScript.create_trim_material(material_preset as _WallMaterialFactoryScript.MaterialPreset)
		mesh.surface_set_material(0, trim_mat)

	# Superficie 1: WallPanel (Cuerpo liso de piedra)
	st_panel.generate_tangents()
	mesh = st_panel.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_name(1, "WallPanel")
		var panel_mat = _WallMaterialFactoryScript.create_panel_material(material_preset as _WallMaterialFactoryScript.MaterialPreset)
		mesh.surface_set_material(1, panel_mat)

	# Superficie 2: Bricks (Ladrillos estilizados en relieve)
	st_bricks.generate_tangents()
	mesh = st_bricks.commit(mesh)
	if mesh.get_surface_count() > 2:
		mesh.surface_set_name(2, "Bricks")
		var brick_mat = _WallMaterialFactoryScript.create_brick_material(material_preset as _WallMaterialFactoryScript.MaterialPreset)
		mesh.surface_set_material(2, brick_mat)

	return mesh

## Distribuye ladrillos estilizados sobre la cara frontal del panel mediante FastNoiseLite.
func _distribute_bricks_on_edge(
	st: SurfaceTool,
	p0: Vector3,
	p1: Vector3,
	edge_len: float,
	tangent: Vector3,
	normal: Vector3,
	config: WallMeshConfig,
	rng: RandomNumberGenerator,
	panel_h: float,
	bot_trim_h: float
) -> void:
	if edge_len < 0.8:
		return

	var noise := FastNoiseLite.new()
	noise.seed = config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = config.noise_frequency

	var bw: float = config.brick_width
	var bh: float = config.brick_height
	var sp: float = 0.022
	var basis := Basis(tangent, Vector3.UP, normal)

	var num_x_slots: int = maxi(2, int(edge_len / (bw * 1.2)))
	var num_y_slots: int = maxi(2, int(panel_h / (bh * 1.6)))

	var step_x: float = edge_len / float(num_x_slots)
	var step_y: float = panel_h / float(num_y_slots)

	for iy in range(num_y_slots):
		var slot_y: float = bot_trim_h + (float(iy) * step_y) + (step_y * 0.5)

		for ix in range(num_x_slots):
			var seg_dist: float = (float(ix) * step_x) + (step_x * 0.5)
			if seg_dist < bw * 0.5 or seg_dist > edge_len - (bw * 0.5):
				continue

			var pt_world: Vector3 = p0 + (tangent * seg_dist)
			var n_val: float = noise.get_noise_3d(pt_world.x * 1.5, slot_y * 2.0, pt_world.z * 1.5)
			var threshold: float = 0.65 - (config.brick_density * 0.95)

			if n_val > threshold:
				var size := _get_random_brick_size(bw, bh, config, rng)
				var jitter_along: float = rng.randf_range(-step_x * 0.2, step_x * 0.2)
				var jitter_y: float = rng.randf_range(-step_y * 0.15, step_y * 0.15)
				var brick_pt: Vector3 = pt_world + (tangent * jitter_along)
				var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

				_append_brick(st, basis, brick_pt, local_pos, size, config, rng)

				if rng.randf() < (config.brick_density * 0.5):
					var size2 := _get_random_brick_size(bw * 0.85, bh, config, rng)
					var pair_y: float = slot_y + jitter_y - bh - sp
					if pair_y > bot_trim_h + (bh * 0.6):
						_append_brick(st, basis, brick_pt, Vector3(rng.randf_range(-bw * 0.3, bw * 0.3), pair_y, 0.0), size2, config, rng)

func _get_random_brick_size(base_w: float, base_h: float, config: WallMeshConfig, rng: RandomNumberGenerator) -> Vector3:
	var w_var: float = rng.randf_range(-config.brick_size_variance, config.brick_size_variance)
	var h_var: float = rng.randf_range(-config.brick_size_variance * 0.5, config.brick_size_variance * 0.5)
	var d_var: float = rng.randf_range(-config.brick_depth_variance, config.brick_depth_variance)

	var w: float = maxf(0.12, base_w * (1.0 + w_var))
	var h: float = maxf(0.06, base_h * (1.0 + h_var))
	var depth: float = maxf(0.015, (config.brick_protrusion * 2.0) * (1.0 + d_var))

	return Vector3(w, h, depth)

func _append_brick(
	st: SurfaceTool,
	run_basis: Basis,
	seg_pos: Vector3,
	local_pos: Vector3,
	size: Vector3,
	config: WallMeshConfig,
	rng: RandomNumberGenerator
) -> void:
	var rot_z: float = rng.randf_range(-config.brick_jitter_rot, config.brick_jitter_rot)
	var brick_basis := run_basis.rotated(run_basis.z, rot_z)
	var world_pos: Vector3 = seg_pos + (run_basis * local_pos)
	var t := Transform3D(brick_basis, world_pos)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, size, t, config.pillowed_bevel)

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
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

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p3)
