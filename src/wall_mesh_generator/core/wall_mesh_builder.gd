class_name WallMeshBuilder
extends RefCounted

## Ensamblador de mallas de pared y esquinas estilizadas.
## Soporta piezas rectas (Wall) y esquinas en L de 90° (Corner) con cornisas a 45°, zócalos y ladrillos en relieve.

const _BrickGeometryBuilderScript = preload("res://src/wall_mesh_generator/core/brick_geometry_builder.gd")

## Genera el manifiesto ordenado de partes según el tipo de pieza (Wall o Corner).
func build_brick_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	if config == null:
		config = WallMeshConfig.new()

	if config.piece_type == WallMeshConfig.PieceType.CORNER:
		return _build_corner_manifest(config)
	else:
		return _build_wall_manifest(config)

# ==============================================================================
# MANIFIESTO PARA ESQUINA EN L (CORNER)
# ==============================================================================
func _build_corner_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	var arm_len: float = config.cube_size
	var total_height: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var part_idx: int = 0

	# 1. Zócalo Inferior en L (Fase 1)
	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"corner_bottom_base",
		"transform": Transform3D(Basis(), Vector3(0.0, bot_y, 0.0))
	})
	part_idx += 1

	# 2. Panel Central de Pared en L (Fase 2)
	var panel_y: float = config.bottom_trim_height + (panel_h * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"corner_wall_panel",
		"transform": Transform3D(Basis(), Vector3(0.0, panel_y, 0.0))
	})
	part_idx += 1

	# 3. Cornisa Superior en L (Fase 3)
	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"corner_top_cornice",
		"transform": Transform3D(Basis(), Vector3(0.0, top_y, 0.0))
	})
	part_idx += 1

	# 4. Ladrillos en Relieve en las Caras de la Esquina
	var bw: float = config.brick_width
	var bh: float = config.brick_height
	var brick_depth: float = config.brick_protrusion * 2.0
	var sp: float = 0.022

	var d: float = config.trim_overhang
	var w_thick: float = config.wall_thickness + (d * 2.0)
	var inner_z: float = (w_thick - d) + (config.brick_protrusion * 0.5)
	var inner_x: float = (w_thick - d) + (config.brick_protrusion * 0.5)

	# --- Brazo X Interior (cara mirando hacia +Z) ---
	var arm_x_center: float = w_thick + ((arm_len - w_thick) * 0.55)
	var arm_x_y: float = config.bottom_trim_height + (panel_h * 0.50)

	# Cluster superior en brazo X interior
	manifest.append(_create_brick_raw(
		part_idx, 3, Vector3(bw * 0.85, bh, brick_depth),
		Vector3(arm_x_center + (bw * 0.1), arm_x_y + (bh * 0.9), inner_z),
		Basis(), config, rng
	))
	part_idx += 1
	manifest.append(_create_brick_raw(
		part_idx, 3, Vector3(bw * 0.80, bh, brick_depth),
		Vector3(arm_x_center + (bw * 0.35), arm_x_y + (bh * 0.9) - bh - sp, inner_z),
		Basis(), config, rng
	))
	part_idx += 1

	# Cluster inferior en brazo X interior
	manifest.append(_create_brick_raw(
		part_idx, 4, Vector3(bw * 0.82, bh, brick_depth),
		Vector3(arm_x_center, config.bottom_trim_height + (panel_h * 0.20), inner_z),
		Basis(), config, rng
	))
	part_idx += 1

	# --- Brazo Z Interior (cara mirando hacia +X, rotada 90° en Y) ---
	var arm_z_center: float = w_thick + ((arm_len - w_thick) * 0.55)
	var arm_z_y: float = config.bottom_trim_height + (panel_h * 0.50)
	var basis_arm_z := Basis().rotated(Vector3.UP, PI * 0.5)

	# Cluster superior en brazo Z interior
	manifest.append(_create_brick_raw(
		part_idx, 3, Vector3(bw * 0.85, bh, brick_depth),
		Vector3(inner_x, arm_z_y + (bh * 0.8), arm_z_center + (bw * 0.15)),
		basis_arm_z, config, rng
	))
	part_idx += 1

	# Cluster inferior en brazo Z interior (2 ladrillos escalonados como en la imagen de esquina)
	manifest.append(_create_brick_raw(
		part_idx, 4, Vector3(bw * 0.80, bh, brick_depth),
		Vector3(inner_x, config.bottom_trim_height + (panel_h * 0.22) + (bh * 0.5), arm_z_center + (bw * 0.1)),
		basis_arm_z, config, rng
	))
	part_idx += 1
	manifest.append(_create_brick_raw(
		part_idx, 4, Vector3(bw * 0.85, bh, brick_depth),
		Vector3(inner_x, config.bottom_trim_height + (panel_h * 0.22) - (bh * 0.5), arm_z_center - (bw * 0.2)),
		basis_arm_z, config, rng
	))
	part_idx += 1

	# --- Caras Exteriores de la Esquina (-Z y -X) ---
	var outer_z: float = d - (config.brick_protrusion * 0.5)
	var outer_x: float = d - (config.brick_protrusion * 0.5)
	var basis_outer_x := Basis().rotated(Vector3.UP, PI)
	var basis_outer_z := Basis().rotated(Vector3.UP, -PI * 0.5)

	manifest.append(_create_brick_raw(
		part_idx, 5, Vector3(bw * 0.85, bh, brick_depth),
		Vector3(arm_x_center, arm_x_y + (bh * 0.5), outer_z),
		basis_outer_x, config, rng
	))
	part_idx += 1

	manifest.append(_create_brick_raw(
		part_idx, 5, Vector3(bw * 0.85, bh, brick_depth),
		Vector3(outer_x, arm_z_y + (bh * 0.5), arm_z_center),
		basis_outer_z, config, rng
	))
	part_idx += 1

	return manifest

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

# ==============================================================================
# MANIFIESTO PARA PARED RECTA (WALL)
# ==============================================================================
func _build_wall_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	var total_length: float = config.get_total_length()
	var total_height: float = config.get_total_height()
	var panel_h: float = config.get_wall_panel_height()

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var part_idx: int = 0

	# 1. Zócalo Inferior Modular (Fase 1)
	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"trim_base",
		"size": Vector3(total_length, config.bottom_trim_height, config.wall_thickness + config.trim_overhang * 2.0),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, bot_y, 0.0)),
		"slope_height": config.bottom_trim_slope_height
	})
	part_idx += 1

	# 2. Panel Central de Pared Base (Fase 2)
	var panel_y: float = config.bottom_trim_height + (panel_h * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"panel",
		"size": Vector3(total_length, panel_h, config.wall_thickness),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, panel_y, 0.0)),
		"bevel": 0.010
	})
	part_idx += 1

	# 3. Cornisa Superior Modular (Fase 3)
	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"trim_cornice",
		"size": Vector3(total_length, config.top_trim_height, config.wall_thickness + config.trim_overhang * 2.0),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, top_y, 0.0)),
		"slope_height": config.top_trim_slope_height
	})
	part_idx += 1

	# 4. Parches de Ladrillos Estilizados
	var num_segments: int = maxi(1, config.wall_length_cubes)
	var segment_w: float = config.cube_size

	for seg in range(num_segments):
		var seg_origin_x: float = float(seg) * segment_w
		var is_odd_segment: bool = (seg % 2 == 1)

		for side in [1, -1]:
			var z_pos: float = (config.wall_thickness * 0.5) + (config.brick_protrusion * 0.5) if side == 1 else -(config.wall_thickness * 0.5) - (config.brick_protrusion * 0.5)
			var brick_depth: float = config.brick_protrusion * 2.0
			var bw: float = config.brick_width
			var bh: float = config.brick_height
			var sp: float = 0.022

			if not is_odd_segment:
				var c1_x: float = seg_origin_x + (segment_w * 0.60) + rng.randf_range(-0.03, 0.03)
				var c1_y: float = config.bottom_trim_height + (panel_h * 0.76) + rng.randf_range(-0.03, 0.03)
				manifest.append(_create_stylized_brick(part_idx, 3, Vector3(bw * 0.85, bh, brick_depth), Vector3(c1_x, c1_y, z_pos), config, rng, side))
				part_idx += 1

				var c2_x: float = seg_origin_x + (segment_w * 0.44) + rng.randf_range(-0.03, 0.03)
				var c2_y: float = config.bottom_trim_height + (panel_h * 0.48) + rng.randf_range(-0.03, 0.03)
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.80, bh, brick_depth), Vector3(c2_x + (bw * 0.12), c2_y + (bh * 0.5) + (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.85, bh, brick_depth), Vector3(c2_x - (bw * 0.38), c2_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.90, bh, brick_depth), Vector3(c2_x + (bw * 0.46), c2_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1

				var c3_x: float = seg_origin_x + (segment_w * 0.46) + rng.randf_range(-0.03, 0.03)
				var c3_y: float = config.bottom_trim_height + (panel_h * 0.20) + rng.randf_range(-0.03, 0.03)
				manifest.append(_create_stylized_brick(part_idx, 5, Vector3(bw * 0.78, bh, brick_depth), Vector3(c3_x + (bw * 0.16), c3_y + (bh * 0.5) + (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 5, Vector3(bw * 0.85, bh, brick_depth), Vector3(c3_x - (bw * 0.22), c3_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
			else:
				var b1_x: float = seg_origin_x + (segment_w * 0.35) + rng.randf_range(-0.03, 0.03)
				var b1_y: float = config.bottom_trim_height + (panel_h * 0.80) + rng.randf_range(-0.03, 0.03)
				manifest.append(_create_stylized_brick(part_idx, 3, Vector3(bw * 0.80, bh, brick_depth), Vector3(b1_x - (bw * 0.15), b1_y + (bh * 0.5) + (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 3, Vector3(bw * 0.85, bh, brick_depth), Vector3(b1_x + (bw * 0.22), b1_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1

				var b2_x: float = seg_origin_x + (segment_w * 0.40) + rng.randf_range(-0.03, 0.03)
				var b2_y: float = config.bottom_trim_height + (panel_h * 0.28) + rng.randf_range(-0.03, 0.03)
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.82, bh, brick_depth), Vector3(b2_x, b2_y + (bh * 0.5) + (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.80, bh, brick_depth), Vector3(b2_x - (bw * 0.42), b2_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1
				manifest.append(_create_stylized_brick(part_idx, 4, Vector3(bw * 0.88, bh, brick_depth), Vector3(b2_x + (bw * 0.42), b2_y - (bh * 0.5) - (sp * 0.5), z_pos), config, rng, side))
				part_idx += 1

	return manifest

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
		var type: StringName = p.get("type", &"")

		match cat:
			&"bottom_trim":
				has_trims = true
				if config.piece_type == WallMeshConfig.PieceType.CORNER:
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
				if config.piece_type == WallMeshConfig.PieceType.CORNER:
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
				if config.piece_type == WallMeshConfig.PieceType.CORNER:
					_BrickGeometryBuilderScript.append_corner_wall_panel(
						st_panel, config.cube_size, config.get_wall_panel_height(),
						config.wall_thickness, p["transform"], p.get("bevel", 0.012)
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
