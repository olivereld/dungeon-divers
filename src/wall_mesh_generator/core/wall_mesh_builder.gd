class_name WallMeshBuilder
extends RefCounted

## Ensamblador de mallas de pared, esquinas y arcos estilizados.
## Utiliza generación procedimental guiada por ruido Simplex (FastNoiseLite) para distribuir
## grupos orgánicos de ladrillos, con variaciones dinámicas de tamaño, relieve, rotación y densidad.

const _BrickGeometryBuilderScript = preload("res://src/wall_mesh_generator/core/brick_geometry_builder.gd")

## Genera el manifiesto ordenado de partes según el tipo de pieza (Wall, Corner o Arch).
func build_brick_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	if config == null:
		config = WallMeshConfig.new()

	match config.piece_type:
		WallMeshConfig.PieceType.ARCH:
			return _build_arch_manifest(config)
		WallMeshConfig.PieceType.CORNER:
			return _build_corner_manifest(config)
		_:
			return _build_wall_manifest(config)

# ==============================================================================
# 1. MANIFIESTO PARA ARCO DE ENTRADA (ARCH / DOORWAY)
# ==============================================================================
func _build_arch_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	var total_width: float = config.cube_size
	var total_height: float = config.get_total_height()
	var offset_x: float = -(total_width * 0.5) if config.centered_origin else 0.0

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var noise := FastNoiseLite.new()
	noise.seed = config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = config.noise_frequency

	var part_idx: int = 0

	# 1. Zócalos de Pilares del Arco (Fase 1)
	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"arch_bottom_base",
		"transform": Transform3D(Basis(), Vector3((total_width * 0.5) + offset_x, bot_y, 0.0))
	})
	part_idx += 1

	# 2. Panel Central de Pared con Vano de Arco Curvado (Fase 2)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"arch_wall_panel",
		"transform": Transform3D(Basis(), Vector3((total_width * 0.5) + offset_x, config.bottom_trim_height, 0.0)),
		"bevel": 0.010
	})
	part_idx += 1

	# 3. Cornisa Superior del Arco (Fase 3)
	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"arch_top_cornice",
		"transform": Transform3D(Basis(), Vector3((total_width * 0.5) + offset_x, top_y, 0.0))
	})
	part_idx += 1

	# 4. Ladrillos Estilizados Dinámicos en los Pilares y Dintel (Guiados por Ruido)
	var pillar_w: float = (total_width - config.arch_opening_width) * 0.5
	var left_pillar_x: float = (pillar_w * 0.5) + offset_x
	var right_pillar_x: float = (total_width - (pillar_w * 0.5)) + offset_x

	var bw: float = config.brick_width * 0.70
	var bh: float = config.brick_height
	var sp: float = 0.022
	var panel_h: float = config.get_wall_panel_height()

	var candidate_y_slots: Array[float] = [
		config.bottom_trim_height + (panel_h * 0.82),
		config.bottom_trim_height + (panel_h * 0.65),
		config.bottom_trim_height + (panel_h * 0.45),
		config.bottom_trim_height + (panel_h * 0.25),
		config.bottom_trim_height + (panel_h * 0.12)
	]

	for side in [1, -1]:
		var z_base: float = (config.wall_thickness * 0.5) if side == 1 else -(config.wall_thickness * 0.5)

		# Evaluar ranuras en Pilar Izquierdo
		for cy in candidate_y_slots:
			var n_val: float = noise.get_noise_2d(left_pillar_x * 2.0, cy * 3.0 + float(side * 50))
			if n_val > (0.65 - (config.brick_density * 0.95)):
				var size := _get_random_brick_size(bw, bh, config, rng)
				var z_pos: float = z_base + ((size.z * 0.5) * float(side))
				var jitter_x: float = rng.randf_range(-0.02, 0.02)
				manifest.append(_create_stylized_brick(
					part_idx, 3, size,
					Vector3(left_pillar_x + jitter_x, cy, z_pos),
					config, rng, side
				))
				part_idx += 1

				# Ocasionalmente añadir ladrillo adyacente (par) si la densidad es alta
				if rng.randf() < config.brick_density * 0.6:
					var size2 := _get_random_brick_size(bw * 0.85, bh, config, rng)
					var cy2: float = cy - bh - sp
					var z_pos2: float = z_base + ((size2.z * 0.5) * float(side))
					manifest.append(_create_stylized_brick(
						part_idx, 3, size2,
						Vector3(left_pillar_x - jitter_x, cy2, z_pos2),
						config, rng, side
					))
					part_idx += 1

		# Evaluar ranuras en Pilar Derecho
		for cy in candidate_y_slots:
			var n_val: float = noise.get_noise_2d(right_pillar_x * 2.0, cy * 3.0 + float(side * 50))
			if n_val > (0.65 - (config.brick_density * 0.95)):
				var size := _get_random_brick_size(bw, bh, config, rng)
				var z_pos: float = z_base + ((size.z * 0.5) * float(side))
				var jitter_x: float = rng.randf_range(-0.02, 0.02)
				manifest.append(_create_stylized_brick(
					part_idx, 4, size,
					Vector3(right_pillar_x + jitter_x, cy, z_pos),
					config, rng, side
				))
				part_idx += 1

	return manifest

# ==============================================================================
# 2. MANIFIESTO PARA ESQUINA EN L (CORNER)
# ==============================================================================
func _build_corner_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	var arm_len: float = config.cube_size
	var total_height: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()
	var offset: Vector3 = Vector3(-arm_len * 0.5, 0.0, -arm_len * 0.5) if config.centered_origin else Vector3.ZERO

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var noise := FastNoiseLite.new()
	noise.seed = config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = config.noise_frequency

	var part_idx: int = 0

	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"corner_bottom_base",
		"transform": Transform3D(Basis(), Vector3(0.0, bot_y, 0.0) + offset)
	})
	part_idx += 1

	var panel_y: float = config.bottom_trim_height + (panel_h * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"corner_wall_panel",
		"transform": Transform3D(Basis(), Vector3(0.0, panel_y, 0.0) + offset)
	})
	part_idx += 1

	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"corner_top_cornice",
		"transform": Transform3D(Basis(), Vector3(0.0, top_y, 0.0) + offset)
	})
	part_idx += 1

	var bw: float = config.brick_width
	var bh: float = config.brick_height
	var d: float = config.trim_overhang
	var w_thick: float = config.wall_thickness + (d * 2.0)
	var inner_z: float = (w_thick - d)
	var inner_x: float = (w_thick - d)

	# Distribución procedural guiada por ruido en Brazo X
	var arm_x_center: float = w_thick + ((arm_len - w_thick) * 0.55)
	var candidate_y_slots: Array[float] = [
		config.bottom_trim_height + (panel_h * 0.78),
		config.bottom_trim_height + (panel_h * 0.50),
		config.bottom_trim_height + (panel_h * 0.22)
	]

	for cy in candidate_y_slots:
		var n_val: float = noise.get_noise_2d(arm_x_center * 2.0, cy * 3.0)
		if n_val > (0.60 - (config.brick_density * 0.90)):
			var size := _get_random_brick_size(bw, bh, config, rng)
			var z_pos: float = inner_z + (size.z * 0.5)
			manifest.append(_create_brick_raw(
				part_idx, 3, size,
				Vector3(arm_x_center + rng.randf_range(-0.04, 0.04), cy, z_pos) + offset,
				Basis(), config, rng
			))
			part_idx += 1

	# Distribución procedural guiada por ruido en Brazo Z
	var arm_z_center: float = w_thick + ((arm_len - w_thick) * 0.55)
	var basis_arm_z := Basis().rotated(Vector3.UP, PI * 0.5)

	for cy in candidate_y_slots:
		var n_val: float = noise.get_noise_2d(arm_z_center * 2.0 + 100.0, cy * 3.0)
		if n_val > (0.60 - (config.brick_density * 0.90)):
			var size := _get_random_brick_size(bw, bh, config, rng)
			var x_pos: float = inner_x + (size.z * 0.5)
			manifest.append(_create_brick_raw(
				part_idx, 4, size,
				Vector3(x_pos, cy, arm_z_center + rng.randf_range(-0.04, 0.04)) + offset,
				basis_arm_z, config, rng
			))
			part_idx += 1

	return manifest

# ==============================================================================
# 3. MANIFIESTO PARA PARED RECTA (WALL)
# ==============================================================================
func _build_wall_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	var total_length: float = config.get_total_length()
	var total_height: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()
	var offset_x: float = -(total_length * 0.5) if config.centered_origin else 0.0

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var noise := FastNoiseLite.new()
	noise.seed = config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = config.noise_frequency

	var part_idx: int = 0

	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"trim_base",
		"size": Vector3(total_length, config.bottom_trim_height, config.wall_thickness + config.trim_overhang * 2.0),
		"transform": Transform3D(Basis(), Vector3((total_length * 0.5) + offset_x, bot_y, 0.0)),
		"slope_height": config.bottom_trim_slope_height
	})
	part_idx += 1

	var panel_y: float = config.bottom_trim_height + (panel_h * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"panel",
		"size": Vector3(total_length, panel_h, config.wall_thickness),
		"transform": Transform3D(Basis(), Vector3((total_length * 0.5) + offset_x, panel_y, 0.0)),
		"bevel": 0.010
	})
	part_idx += 1

	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"trim_cornice",
		"size": Vector3(total_length, config.top_trim_height, config.wall_thickness + config.trim_overhang * 2.0),
		"transform": Transform3D(Basis(), Vector3((total_length * 0.5) + offset_x, top_y, 0.0)),
		"slope_height": config.top_trim_slope_height
	})
	part_idx += 1

	# Distribución Dinámica de Ladrillos con Ruido y Muestreo Espacial
	var bw: float = config.brick_width
	var bh: float = config.brick_height
	var sp: float = 0.025

	var num_x_slots: int = maxi(2, int(total_length / (bw * 1.1)))
	var num_y_slots: int = maxi(2, int(panel_h / (bh * 1.5)))

	var step_x: float = total_length / float(num_x_slots)
	var step_y: float = panel_h / float(num_y_slots)

	for side in [1, -1]:
		var z_base: float = (config.wall_thickness * 0.5) if side == 1 else -(config.wall_thickness * 0.5)

		for iy in range(num_y_slots):
			var slot_y: float = config.bottom_trim_height + (float(iy) * step_y) + (step_y * 0.5)

			for ix in range(num_x_slots):
				var slot_x: float = offset_x + (float(ix) * step_x) + (step_x * 0.5)

				# Muestrear ruido en coordenadas mundo 2D
				var n_val: float = noise.get_noise_2d(slot_x * 1.5, slot_y * 2.0 + float(side * 80))
				var threshold: float = 0.65 - (config.brick_density * 0.95)

				if n_val > threshold:
					var size := _get_random_brick_size(bw, bh, config, rng)
					var pos_x: float = slot_x + rng.randf_range(-step_x * 0.2, step_x * 0.2)
					var pos_y: float = slot_y + rng.randf_range(-step_y * 0.15, step_y * 0.15)
					var z_pos: float = z_base + ((size.z * 0.5) * float(side))

					manifest.append(_create_stylized_brick(
						part_idx, 3 + (iy % 3), size,
						Vector3(pos_x, pos_y, z_pos),
						config, rng, side
					))
					part_idx += 1

					# Posibilidad de agrupar en pareja o trío (*Cluster Effect*)
					if rng.randf() < (config.brick_density * 0.55):
						var size2 := _get_random_brick_size(bw * 0.85, bh, config, rng)
						var pair_offset_x: float = rng.randf_range(-bw * 0.4, bw * 0.4)
						var pair_y: float = pos_y - bh - sp
						if pair_y > config.bottom_trim_height + (bh * 0.6):
							var z_pos2: float = z_base + ((size2.z * 0.5) * float(side))
							manifest.append(_create_stylized_brick(
								part_idx, 3 + (iy % 3), size2,
								Vector3(pos_x + pair_offset_x, pair_y, z_pos2),
								config, rng, side
							))
							part_idx += 1

	return manifest

func _get_random_brick_size(base_w: float, base_h: float, config: WallMeshConfig, rng: RandomNumberGenerator) -> Vector3:
	var w_var: float = rng.randf_range(-config.brick_size_variance, config.brick_size_variance)
	var h_var: float = rng.randf_range(-config.brick_size_variance * 0.5, config.brick_size_variance * 0.5)
	var d_var: float = rng.randf_range(-config.brick_depth_variance, config.brick_depth_variance)

	var w: float = maxf(0.12, base_w * (1.0 + w_var))
	var h: float = maxf(0.06, base_h * (1.0 + h_var))
	var depth: float = maxf(0.015, (config.brick_protrusion * 2.0) * (1.0 + d_var))

	return Vector3(w, h, depth)

func _create_brick_raw(
	idx: int, course: int, size: Vector3,
	pos: Vector3, base_basis: Basis,
	config: WallMeshConfig, rng: RandomNumberGenerator
) -> Dictionary:
	var rot_z: float = rng.randf_range(-config.brick_jitter_rot, config.brick_jitter_rot)
	var basis := base_basis.rotated(Vector3.FORWARD, rot_z)
	var t := Transform3D(basis, pos)

	return {
		"index": idx,
		"category": &"brick",
		"course": course,
		"type": &"stylized_brick",
		"size": size,
		"transform": t,
		"bevel": config.pillowed_bevel
	}

func _create_stylized_brick(
	idx: int, course: int, size: Vector3,
	pos: Vector3, config: WallMeshConfig,
	rng: RandomNumberGenerator, side: int
) -> Dictionary:
	var rot_z: float = rng.randf_range(-config.brick_jitter_rot, config.brick_jitter_rot)
	var basis := Basis().rotated(Vector3.FORWARD, rot_z)
	if side == -1:
		basis = basis.rotated(Vector3.UP, PI)
	var t := Transform3D(basis, pos)

	return {
		"index": idx,
		"category": &"brick",
		"course": course,
		"type": &"stylized_brick",
		"size": size,
		"transform": t,
		"bevel": config.pillowed_bevel,
		"side": side
	}

## Construye el ArrayMesh completo según la configuración dada.
func build_wall_mesh(config: WallMeshConfig) -> ArrayMesh:
	var manifest: Array[Dictionary] = build_brick_manifest(config)
	return build_mesh_from_subset(config, manifest.size(), manifest)

## Construye la submalla con las primeras `count` partes activas del manifiesto.
func build_mesh_from_subset(
	config: WallMeshConfig,
	count: int,
	cached_manifest: Array[Dictionary] = []
) -> ArrayMesh:
	if config == null:
		config = WallMeshConfig.new()

	var manifest: Array[Dictionary] = cached_manifest if not cached_manifest.is_empty() else build_brick_manifest(config)
	var active_count: int = clampi(count, 0, manifest.size())
	if active_count <= 0:
		return ArrayMesh.new()

	var st_trims := SurfaceTool.new()
	var st_panel := SurfaceTool.new()
	var st_bricks := SurfaceTool.new()

	var has_trims: bool = false
	var has_panel: bool = false
	var has_bricks: bool = false

	st_trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(active_count):
		var p: Dictionary = manifest[i]
		var cat: StringName = p["category"]

		match cat:
			&"bottom_trim":
				has_trims = true
				if config.piece_type == WallMeshConfig.PieceType.ARCH:
					_BrickGeometryBuilderScript.append_arch_bottom_base(
						st_trims, config.cube_size,
						config.bottom_trim_height, config.bottom_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						config.arch_opening_width, p["transform"]
					)
				elif config.piece_type == WallMeshConfig.PieceType.CORNER:
					_BrickGeometryBuilderScript.append_corner_bottom_base(
						st_trims, config.cube_size,
						config.bottom_trim_height, config.bottom_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						p["transform"], config.notch_width, config.notch_depth,
						config.corner_outer_chamfer
					)
				else:
					_BrickGeometryBuilderScript.append_modular_bottom_base(
						st_trims, config.get_total_length(), config.cube_size,
						config.bottom_trim_height, config.bottom_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						p["transform"], config.notch_width, config.notch_depth
					)

			&"top_trim":
				has_trims = true
				if config.piece_type == WallMeshConfig.PieceType.ARCH:
					_BrickGeometryBuilderScript.append_arch_top_cornice(
						st_trims, config.cube_size,
						config.top_trim_height, config.top_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						p["transform"], config.notch_width, config.notch_depth
					)
				elif config.piece_type == WallMeshConfig.PieceType.CORNER:
					_BrickGeometryBuilderScript.append_corner_top_cornice(
						st_trims, config.cube_size,
						config.top_trim_height, config.top_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						p["transform"], config.notch_width, config.notch_depth,
						config.corner_outer_chamfer
					)
				else:
					_BrickGeometryBuilderScript.append_modular_top_trim(
						st_trims, config.get_total_length(), config.cube_size,
						config.top_trim_height, config.top_trim_slope_height,
						config.wall_thickness, config.trim_overhang,
						p["transform"], config.notch_width, config.notch_depth
					)

			&"wall_panel":
				has_panel = true
				if config.piece_type == WallMeshConfig.PieceType.ARCH:
					_BrickGeometryBuilderScript.append_arch_wall_panel(
						st_panel, config.cube_size, config.get_wall_panel_height(),
						config.wall_thickness, config.arch_opening_width,
						config.arch_opening_height - config.bottom_trim_height,
						config.arch_inner_bevel, p["transform"], p.get("bevel", 0.012)
					)
				elif config.piece_type == WallMeshConfig.PieceType.CORNER:
					_BrickGeometryBuilderScript.append_corner_wall_panel(
						st_panel, config.cube_size, config.get_wall_panel_height(),
						config.wall_thickness, p["transform"], p.get("bevel", 0.012),
						config.trim_overhang, config.corner_outer_chamfer
					)
				else:
					_BrickGeometryBuilderScript.append_beveled_box(
						st_panel, p["size"], p["transform"], p.get("bevel", 0.012)
					)

			&"brick":
				has_bricks = true
				_BrickGeometryBuilderScript.append_pillowed_brick(
					st_bricks, p["size"], p["transform"], p["bevel"]
				)

	var mesh := ArrayMesh.new()

	# Superficie 0: Trims / Molduras
	if has_trims:
		st_trims.generate_tangents()
		mesh = st_trims.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "Trims")

	# Superficie 1: Panel de Pared
	if has_panel:
		st_panel.generate_tangents()
		mesh = st_panel.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "WallPanel")

	# Superficie 2: Ladrillos en Relieve
	if has_bricks:
		st_bricks.generate_tangents()
		mesh = st_bricks.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "Bricks")

	return mesh
