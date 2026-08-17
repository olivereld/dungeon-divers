class_name WallMeshBuilder
extends RefCounted

## Ensamblador de mallas de pared estilizadas y mampostería.
## Genera:
## - Superficie 0: Molduras superior e inferior con junta vertical (Trims)
## - Superficie 1: Panel central liso (WallPanel)
## - Superficie 2: Ladrillos en relieve redondeados estilizados (Bricks)

const _BrickGeometryBuilderScript = preload("res://src/wall_mesh_generator/core/brick_geometry_builder.gd")

## Genera la lista completa y ordenada de partes/ladrillos para la pared configurada.
func build_brick_manifest(config: WallMeshConfig) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	if config == null:
		config = WallMeshConfig.new()

	var total_length: float = config.get_total_length()
	var total_height: float = config.get_total_height()
	var trim_depth: float = config.wall_thickness + (config.trim_overhang * 2.0)
	var panel_h: float = config.get_wall_panel_height()

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var part_idx: int = 0

	# 1. Zócalo / Moldura Inferior (Fase 1 de construcción)
	var bot_y: float = config.bottom_trim_height * 0.5
	manifest.append({
		"index": part_idx,
		"category": &"bottom_trim",
		"course": 0,
		"type": &"trim",
		"size": Vector3(total_length, config.bottom_trim_height, trim_depth),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, bot_y, 0.0)),
		"bevel": 0.015,
		"notch_width": config.trim_notch_width
	})
	part_idx += 1

	# 2. Panel Central de Pared Base (Fase 2 de construcción)
	var panel_y: float = config.bottom_trim_height + (panel_h * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"wall_panel",
		"course": 1,
		"type": &"panel",
		"size": Vector3(total_length, panel_h, config.wall_thickness),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, panel_y, 0.0)),
		"bevel": 0.012,
		"notch_width": 0.0
	})
	part_idx += 1

	# 3. Moldura Superior (Fase 3 de construcción)
	var top_y: float = total_height - (config.top_trim_height * 0.5)
	manifest.append({
		"index": part_idx,
		"category": &"top_trim",
		"course": 2,
		"type": &"trim",
		"size": Vector3(total_length, config.top_trim_height, trim_depth),
		"transform": Transform3D(Basis(), Vector3(total_length * 0.5, top_y, 0.0)),
		"bevel": 0.015,
		"notch_width": config.trim_notch_width
	})
	part_idx += 1

	# 4. Parches de Ladrillos Estilizados en Relieve (Fase 4+ de construcción)
	var num_segments: int = maxi(1, config.wall_length_cubes)
	var segment_w: float = config.cube_size

	for seg in range(num_segments):
		var seg_origin_x: float = float(seg) * segment_w

		# Para cara frontal (+Z) y cara trasera (-Z)
		for side in [1, -1]:
			var z_front: float = (config.wall_thickness * 0.5) + (config.brick_protrusion * 0.5) if side == 1 else -(config.wall_thickness * 0.5) - (config.brick_protrusion * 0.5)
			var brick_depth: float = config.brick_protrusion * 2.0

			# Cluster 1 (Superior): 1 ladrillo individual arriba a la derecha (según imagen)
			var c1_x: float = seg_origin_x + (segment_w * 0.62) + rng.randf_range(-0.05, 0.05)
			var c1_y: float = config.bottom_trim_height + (panel_h * 0.78) + rng.randf_range(-0.04, 0.04)
			manifest.append(_create_stylized_brick(
				part_idx, 3, Vector3(config.brick_width * 0.85, config.brick_height, brick_depth),
				Vector3(c1_x, c1_y, z_front), config, rng, side
			))
			part_idx += 1

			# Cluster 2 (Medio): Grupo piramidal de 3 ladrillos (1 arriba, 2 abajo)
			var c2_center_x: float = seg_origin_x + (segment_w * 0.45) + rng.randf_range(-0.05, 0.05)
			var c2_center_y: float = config.bottom_trim_height + (panel_h * 0.50) + rng.randf_range(-0.04, 0.04)
			var bw: float = config.brick_width
			var bh: float = config.brick_height
			var sp: float = 0.02 # separación

			# Ladrillo superior del grupo central
			manifest.append(_create_stylized_brick(
				part_idx, 4, Vector3(bw * 0.8, bh, brick_depth),
				Vector3(c2_center_x + (bw * 0.1), c2_center_y + (bh * 0.5) + (sp * 0.5), z_front),
				config, rng, side
			))
			part_idx += 1

			# Ladrillo inferior izquierdo del grupo central
			manifest.append(_create_stylized_brick(
				part_idx, 4, Vector3(bw * 0.85, bh, brick_depth),
				Vector3(c2_center_x - (bw * 0.4), c2_center_y - (bh * 0.5) - (sp * 0.5), z_front),
				config, rng, side
			))
			part_idx += 1

			# Ladrillo inferior derecho del grupo central
			manifest.append(_create_stylized_brick(
				part_idx, 4, Vector3(bw * 0.9, bh, brick_depth),
				Vector3(c2_center_x + (bw * 0.45), c2_center_y - (bh * 0.5) - (sp * 0.5), z_front),
				config, rng, side
			))
			part_idx += 1

			# Cluster 3 (Inferior): 2 ladrillos escalonados abajo
			var c3_x: float = seg_origin_x + (segment_w * 0.48) + rng.randf_range(-0.05, 0.05)
			var c3_y: float = config.bottom_trim_height + (panel_h * 0.22) + rng.randf_range(-0.04, 0.04)

			manifest.append(_create_stylized_brick(
				part_idx, 5, Vector3(bw * 0.75, bh, brick_depth),
				Vector3(c3_x + (bw * 0.15), c3_y + (bh * 0.5) + (sp * 0.5), z_front),
				config, rng, side
			))
			part_idx += 1

			manifest.append(_create_stylized_brick(
				part_idx, 5, Vector3(bw * 0.85, bh, brick_depth),
				Vector3(c3_x - (bw * 0.2), c3_y - (bh * 0.5) - (sp * 0.5), z_front),
				config, rng, side
			))
			part_idx += 1

	return manifest

func _create_stylized_brick(
	idx: int, course: int, size: Vector3,
	pos: Vector3, config: WallMeshConfig,
	rng: RandomNumberGenerator, side: int
) -> Dictionary:
	var rot_z: float = rng.randf_range(-config.brick_jitter_rot, config.brick_jitter_rot)
	var basis := Basis().rotated(Vector3.FORWARD, rot_z)
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

## Construye el ArrayMesh completo de la pared.
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
			&"bottom_trim", &"top_trim":
				has_trims = true
				var sz: Vector3 = p["size"]
				var notch: float = p.get("notch_width", 0.035)
				_BrickGeometryBuilderScript.append_trim_beam_with_notch(
					st_trims, sz.x, sz.y, sz.z, p["transform"], notch, p["bevel"]
				)

			&"wall_panel":
				has_panel = true
				_BrickGeometryBuilderScript.append_beveled_box(
					st_panel, p["size"], p["transform"], p["bevel"]
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
