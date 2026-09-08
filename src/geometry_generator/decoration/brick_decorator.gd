class_name BrickDecorator
extends RefCounted

## Decorador superficial procedimental de ladrillos estilizados en relieve (Fase M4).
## Añade la superficie de ladrillos (Bricks) a un GeneratedMesh sin mutar la topología estructural base,
## excluyendo ladrillos dentro de la zona de exclusión de esquinas para evitar colisiones visuales.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _BrickGeometryBuilderScript = preload("res://src/wall_mesh_generator/core/brick_geometry_builder.gd")

func decorate_section(
	g_mesh: _GeneratedMeshScript,
	section: _WallSectionScript,
	geom_config: _WallGeometryConfigScript,
	dec_config: _DecorationConfigScript,
	grid: CellGrid = null
) -> void:
	if section == null:
		return
	var sec_dec_configs := {section: dec_config}
	decorate_sections(g_mesh, [section], geom_config, sec_dec_configs, grid)

func decorate_sections(
	g_mesh: _GeneratedMeshScript,
	sections: Array,
	geom_config: _WallGeometryConfigScript,
	sec_dec_configs: Dictionary = {},
	grid: CellGrid = null
) -> void:
	if g_mesh == null or g_mesh.mesh == null or sections.is_empty():
		return

	if geom_config == null:
		geom_config = _WallGeometryConfigScript.new()

	var st_bricks := SurfaceTool.new()
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_bricks: bool = false

	for sec in sections:
		var section = sec as _WallSectionScript
		if section == null or section.points.size() < 2:
			continue

		var dec_config: _DecorationConfigScript = sec_dec_configs.get(section, null)
		if dec_config == null or not dec_config.enabled or dec_config.style == _DecorationConfigScript.DecorationStyle.NONE:
			continue

		if _append_section_decoration(st_bricks, section, geom_config, dec_config, grid):
			has_bricks = true

	if has_bricks:
		st_bricks.generate_normals()
		st_bricks.index()
		st_bricks.generate_tangents()
		g_mesh.mesh = st_bricks.commit(g_mesh.mesh)
		var surf_idx: int = g_mesh.mesh.get_surface_count() - 1
		g_mesh.mesh.surface_set_name(surf_idx, "Bricks")

func _append_section_decoration(
	st_bricks: SurfaceTool,
	section: _WallSectionScript,
	geom_config: _WallGeometryConfigScript,
	dec_config: _DecorationConfigScript,
	grid: CellGrid
) -> bool:
	var tile_size: float = geom_config.cube_size
	var panel_h: float = geom_config.get_wall_panel_height()
	var bot_trim_h: float = geom_config.bottom_trim_height
	var excl_dist: float = dec_config.corner_exclusion_distance
	var corner_pts := _get_corner_positions(section, tile_size)

	var noise := FastNoiseLite.new()
	noise.seed = dec_config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = dec_config.noise_frequency

	var rng := RandomNumberGenerator.new()
	rng.seed = dec_config.seed + section.id * 17

	var bw: float = dec_config.brick_width
	var bh: float = dec_config.brick_height
	var sp: float = 0.022
	var has_bricks: bool = false

	var pts_count: int = section.points.size()
	var seg_count: int = pts_count if section.is_closed_loop else (pts_count - 1)

	var is_niche: bool = (section.variant_id == &"niche" or section.variant_id == &"niche_alcove")
	var is_ornate: bool = (section.variant_id == &"ornate")
	var is_cracked: bool = (section.variant_id == &"cracked" or section.variant_id == &"damaged")

	for i in range(seg_count):
		var pt0: Vector2i = section.points[i]
		var pt1: Vector2i = section.points[(i + 1) % pts_count]

		var p0 := Vector3(float(pt0.x) * tile_size, 0.0, float(pt0.y) * tile_size)
		var p1 := Vector3(float(pt1.x) * tile_size, 0.0, float(pt1.y) * tile_size)

		var edge_vec: Vector3 = p1 - p0
		var edge_len: float = edge_vec.length()
		if edge_len < 0.8:
			continue

		var tangent: Vector3 = edge_vec.normalized()
		var normal: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var basis := Basis(tangent, Vector3.UP, normal)

		if is_niche:
			_append_niche_decoration(st_bricks, basis, p0, p1, tangent, normal, edge_len, bot_trim_h, panel_h, dec_config, rng)
			has_bricks = true

			var niche_half_w: float = minf(1.50, edge_len * 0.70) * 0.5 + 0.18
			var niche_max_y: float = (bot_trim_h + 0.45) + 1.10 + (minf(1.50, edge_len * 0.70) * 0.5) + 0.12
			var half_len: float = edge_len * 0.5

			var num_x_slots: int = maxi(2, int(edge_len / (bw * 1.35)))
			var num_y_slots: int = maxi(2, int(panel_h / (bh * 1.7)))
			var step_x: float = edge_len / float(num_x_slots)
			var step_y: float = panel_h / float(num_y_slots)

			for iy in range(num_y_slots):
				var slot_y: float = bot_trim_h + (float(iy) * step_y) + (step_y * 0.5)
				for ix in range(num_x_slots):
					var seg_dist: float = (float(ix) * step_x) + (step_x * 0.5)
					var dist_from_mid: float = absf(seg_dist - half_len)
					if dist_from_mid < niche_half_w and slot_y < niche_max_y:
						continue
					if seg_dist < bw * 0.5 or seg_dist > edge_len - (bw * 0.5):
						continue

					var pt_world: Vector3 = p0 + (tangent * seg_dist)
					var n_val: float = noise.get_noise_3d(pt_world.x * 1.5, slot_y * 2.0, pt_world.z * 1.5)
					if n_val > 0.22:
						var size := _get_random_brick_size(bw * 0.88, bh * 0.95, dec_config, rng)
						var jitter_along: float = rng.randf_range(-step_x * 0.15, step_x * 0.15)
						var jitter_y: float = rng.randf_range(-step_y * 0.10, step_y * 0.10)
						var brick_pt: Vector3 = pt_world + (tangent * jitter_along)
						if _is_near_corner(brick_pt, size.x * 0.5, corner_pts, excl_dist):
							continue
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)
						_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						has_bricks = true
		elif is_ornate:
			_append_ornate_decoration(st_bricks, basis, p0, p1, tangent, normal, edge_len, bot_trim_h, panel_h, dec_config, rng)
			has_bricks = true
		else:
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
					var threshold: float = 0.65 - (dec_config.brick_density * 0.95)

					if n_val > threshold:
						var size := _get_random_brick_size(bw, bh, dec_config, rng)
						var jitter_along: float = rng.randf_range(-step_x * 0.2, step_x * 0.2)
						var jitter_y: float = rng.randf_range(-step_y * 0.15, step_y * 0.15)
						var brick_pt: Vector3 = pt_world + (tangent * jitter_along)
						if _is_near_corner(brick_pt, size.x * 0.5, corner_pts, excl_dist):
							continue
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

						if is_cracked and rng.randf() < 0.65:
							_append_broken_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						else:
							_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						has_bricks = true

						if rng.randf() < (dec_config.brick_density * 0.5):
							var size2 := _get_random_brick_size(bw * 0.85, bh, dec_config, rng)
							var pair_jitter_x: float = rng.randf_range(-bw * 0.3, bw * 0.3)
							var pair_pt: Vector3 = brick_pt + (tangent * pair_jitter_x)
							if not _is_near_corner(pair_pt, size2.x * 0.5, corner_pts, excl_dist):
								var pair_y: float = slot_y + jitter_y - bh - sp
								if pair_y > bot_trim_h + (bh * 0.6):
									if is_cracked and rng.randf() < 0.50:
										_append_broken_brick(st_bricks, basis, brick_pt, Vector3(pair_jitter_x, pair_y, 0.0), size2, dec_config, rng)
									else:
										_append_brick(st_bricks, basis, brick_pt, Vector3(pair_jitter_x, pair_y, 0.0), size2, dec_config, rng)
									has_bricks = true

		# Decoración en cara trasera cuando está expuesta
		if grid != null:
			var w_thick: float = geom_config.wall_thickness + (geom_config.trim_overhang * 2.0)
			if _decorate_back_face_slots(st_bricks, p0, tangent, normal, edge_len, bot_trim_h, panel_h, bw, bh, sp, w_thick, tile_size, dec_config, noise, rng, grid, corner_pts, excl_dist):
				has_bricks = true

	return has_bricks

func decorate_component(
	g_mesh: GeneratedMesh,
	component: WallComponent,
	geom_config: WallGeometryConfig,
	dec_config: DecorationConfig,
	grid: CellGrid = null
) -> void:
	if g_mesh == null or g_mesh.mesh == null or component == null or dec_config == null:
		return

	if not dec_config.enabled or dec_config.style == _DecorationConfigScript.DecorationStyle.NONE:
		return

	if geom_config == null:
		geom_config = _WallGeometryConfigScript.new()

	var tile_size: float = geom_config.cube_size
	var panel_h: float = geom_config.get_wall_panel_height()
	var bot_trim_h: float = geom_config.bottom_trim_height
	var excl_dist: float = dec_config.corner_exclusion_distance

	var noise := FastNoiseLite.new()
	noise.seed = dec_config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = dec_config.noise_frequency

	var rng := RandomNumberGenerator.new()
	rng.seed = dec_config.seed

	var st_bricks := SurfaceTool.new()
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bw: float = dec_config.brick_width
	var bh: float = dec_config.brick_height
	var sp: float = 0.022
	var has_bricks: bool = false

	for loop_pts in component.loops:
		var n: int = loop_pts.size()
		if n < 3:
			continue

		var corner_pts := _get_component_corner_positions(loop_pts, tile_size)

		for i in range(n):
			var pt0: Vector2i = loop_pts[i] as Vector2i
			var pt1: Vector2i = loop_pts[(i + 1) % n] as Vector2i

			var p0 := Vector3(float(pt0.x) * tile_size, 0.0, float(pt0.y) * tile_size)
			var p1 := Vector3(float(pt1.x) * tile_size, 0.0, float(pt1.y) * tile_size)

			var edge_vec: Vector3 = p1 - p0
			var edge_len: float = edge_vec.length()
			if edge_len < 0.8:
				continue

			var tangent: Vector3 = edge_vec.normalized()
			var normal: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
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
					var threshold: float = 0.65 - (dec_config.brick_density * 0.95)

					if n_val > threshold:
						var size := _get_random_brick_size(bw, bh, dec_config, rng)
						var jitter_along: float = rng.randf_range(-step_x * 0.2, step_x * 0.2)
						var jitter_y: float = rng.randf_range(-step_y * 0.15, step_y * 0.15)
						var brick_pt: Vector3 = pt_world + (tangent * jitter_along)
						if _is_near_corner(brick_pt, size.x * 0.5, corner_pts, excl_dist):
							continue
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

						_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						has_bricks = true

						if rng.randf() < (dec_config.brick_density * 0.5):
							var size2 := _get_random_brick_size(bw * 0.85, bh, dec_config, rng)
							var pair_jitter_x: float = rng.randf_range(-bw * 0.3, bw * 0.3)
							var pair_pt: Vector3 = brick_pt + (tangent * pair_jitter_x)
							if not _is_near_corner(pair_pt, size2.x * 0.5, corner_pts, excl_dist):
								var pair_y: float = slot_y + jitter_y - bh - sp
								if pair_y > bot_trim_h + (bh * 0.6):
									_append_brick(st_bricks, basis, brick_pt, Vector3(pair_jitter_x, pair_y, 0.0), size2, dec_config, rng)

			if grid != null:
				var w_thick: float = geom_config.wall_thickness + (geom_config.trim_overhang * 2.0)
				if _decorate_back_face_slots(st_bricks, p0, tangent, normal, edge_len, bot_trim_h, panel_h, bw, bh, sp, w_thick, tile_size, dec_config, noise, rng, grid, corner_pts, excl_dist):
					has_bricks = true

	if has_bricks:
		st_bricks.generate_normals()
		st_bricks.index()
		st_bricks.generate_tangents()
		g_mesh.mesh = st_bricks.commit(g_mesh.mesh)
		var surf_idx: int = g_mesh.mesh.get_surface_count() - 1
		g_mesh.mesh.surface_set_name(surf_idx, "Bricks")

func _get_corner_positions(section: _WallSectionScript, tile_size: float) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var pts := section.points
	var n: int = pts.size()
	if n < 2:
		return corners

	if section.is_closed_loop:
		for i in range(n):
			var prev_pt: Vector2i = pts[(i - 1 + n) % n]
			var curr_pt: Vector2i = pts[i]
			var next_pt: Vector2i = pts[(i + 1) % n]
			if (curr_pt - prev_pt) != (next_pt - curr_pt):
				corners.append(Vector3(float(curr_pt.x) * tile_size, 0.0, float(curr_pt.y) * tile_size))
	else:
		for i in range(1, n - 1):
			var v_prev: Vector2i = pts[i] - pts[i - 1]
			var v_next: Vector2i = pts[i + 1] - pts[i]
			if v_prev != v_next:
				corners.append(Vector3(float(pts[i].x) * tile_size, 0.0, float(pts[i].y) * tile_size))

		if section.start_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
			var v_prev: Vector2i = pts[0] - section.start_miter_neighbor
			var v_next: Vector2i = pts[1] - pts[0]
			if v_prev != v_next:
				corners.append(Vector3(float(pts[0].x) * tile_size, 0.0, float(pts[0].y) * tile_size))

		if section.end_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
			var v_prev: Vector2i = pts[n - 1] - pts[n - 2]
			var v_next: Vector2i = section.end_miter_neighbor - pts[n - 1]
			if v_prev != v_next:
				corners.append(Vector3(float(pts[n - 1].x) * tile_size, 0.0, float(pts[n - 1].y) * tile_size))

	return corners

func _get_component_corner_positions(loop_pts: Array, tile_size: float) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var n: int = loop_pts.size()
	if n < 3:
		return corners
	for i in range(n):
		var prev_pt: Vector2i = loop_pts[(i - 1 + n) % n] as Vector2i
		var curr_pt: Vector2i = loop_pts[i] as Vector2i
		var next_pt: Vector2i = loop_pts[(i + 1) % n] as Vector2i
		if (curr_pt - prev_pt) != (next_pt - curr_pt):
			corners.append(Vector3(float(curr_pt.x) * tile_size, 0.0, float(curr_pt.y) * tile_size))
	return corners

func _is_near_corner(pos: Vector3, radius: float, corners: Array[Vector3], min_dist: float) -> bool:
	if min_dist <= 0.0001 or corners.is_empty():
		return false
	var required := min_dist + radius
	var req_sq := required * required
	for cp in corners:
		if Vector2(pos.x - cp.x, pos.z - cp.z).length_squared() < req_sq:
			return true
	return false

func _get_random_brick_size(base_w: float, base_h: float, config: DecorationConfig, rng: RandomNumberGenerator) -> Vector3:
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
	config: DecorationConfig,
	rng: RandomNumberGenerator
) -> void:
	var rot_z: float = rng.randf_range(-config.brick_jitter_rot, config.brick_jitter_rot)
	var brick_basis := run_basis.rotated(run_basis.z, rot_z)
	var world_pos: Vector3 = seg_pos + (run_basis * local_pos)
	var t := Transform3D(brick_basis, world_pos)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, size, t, config.pillowed_bevel)

func _append_broken_brick(
	st: SurfaceTool,
	run_basis: Basis,
	seg_pos: Vector3,
	local_pos: Vector3,
	size: Vector3,
	config: DecorationConfig,
	rng: RandomNumberGenerator
) -> void:
	var crack_mode: int = rng.randi() % 3
	match crack_mode:
		0:
			# Partición en dos trozos con fisura/grieta visible
			var split_ratio: float = rng.randf_range(0.40, 0.60)
			var gap: float = 0.035
			var w1: float = (size.x * split_ratio) - (gap * 0.5)
			var w2: float = (size.x * (1.0 - split_ratio)) - (gap * 0.5)
			if w1 > 0.05 and w2 > 0.05:
				var rot1: float = rng.randf_range(-0.12, 0.05)
				var rot2: float = rng.randf_range(-0.05, 0.12)
				var b_basis1 := run_basis.rotated(run_basis.z, rot1)
				var b_basis2 := run_basis.rotated(run_basis.z, rot2)

				var offset_x1: float = -size.x * 0.5 + w1 * 0.5
				var offset_x2: float = size.x * 0.5 - w2 * 0.5
				var shift_y1: float = rng.randf_range(-0.015, 0.015)
				var shift_y2: float = rng.randf_range(-0.02, 0.02)

				var pos1: Vector3 = seg_pos + (run_basis * (local_pos + Vector3(offset_x1, shift_y1, rng.randf_range(-0.01, 0.01))))
				var pos2: Vector3 = seg_pos + (run_basis * (local_pos + Vector3(offset_x2, shift_y2, rng.randf_range(-0.01, 0.015))))

				_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(w1, size.y * rng.randf_range(0.85, 1.0), size.z), Transform3D(b_basis1, pos1), config.pillowed_bevel * 0.8)
				_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(w2, size.y * rng.randf_range(0.85, 1.0), size.z), Transform3D(b_basis2, pos2), config.pillowed_bevel * 0.8)
			else:
				_append_brick(st, run_basis, seg_pos, local_pos, size, config, rng)
		1:
			# Ladrillo astillado: bloque principal y fragmento desprendido
			var main_w: float = size.x * rng.randf_range(0.60, 0.75)
			var rot_main: float = rng.randf_range(-0.10, 0.10)
			var b_basis := run_basis.rotated(run_basis.z, rot_main)
			var pos_main: Vector3 = seg_pos + (run_basis * (local_pos + Vector3(-size.x * 0.12, 0.0, 0.0)))
			_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(main_w, size.y, size.z), Transform3D(b_basis, pos_main), config.pillowed_bevel)

			var shard_w: float = size.x * rng.randf_range(0.18, 0.25)
			var shard_h: float = size.y * rng.randf_range(0.40, 0.60)
			var rot_shard: float = rng.randf_range(-0.25, 0.25)
			var pos_shard: Vector3 = seg_pos + (run_basis * (local_pos + Vector3(size.x * 0.35, rng.randf_range(-0.03, 0.01), 0.01)))
			_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(shard_w, shard_h, size.z * 0.8), Transform3D(run_basis.rotated(run_basis.z, rot_shard), pos_shard), config.pillowed_bevel * 0.6)
		2:
			# Ladrillo desalineado, descolocado y sobresaliente
			var rot_tilt: float = rng.randf_range(-0.16, 0.16)
			var b_basis := run_basis.rotated(run_basis.z, rot_tilt).rotated(run_basis.x, rng.randf_range(-0.08, 0.08))
			var world_pos: Vector3 = seg_pos + (run_basis * (local_pos + Vector3(0.0, rng.randf_range(-0.02, 0.02), rng.randf_range(-0.015, 0.025))))
			_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(size.x * 0.90, size.y * 0.92, size.z), Transform3D(b_basis, world_pos), config.pillowed_bevel)

func _append_niche_decoration(
	st: SurfaceTool,
	basis: Basis,
	p0: Vector3,
	p1: Vector3,
	tangent: Vector3,
	normal: Vector3,
	edge_len: float,
	bot_trim_h: float,
	panel_h: float,
	config: DecorationConfig,
	rng: RandomNumberGenerator
) -> void:
	var seg_center: Vector3 = (p0 + p1) * 0.5
	var niche_w: float = minf(1.50, edge_len * 0.70)
	var sill_y: float = bot_trim_h + 0.45
	var sill_h: float = 0.12
	var sill_d: float = 0.22
	var jamba_h: float = 1.05
	var arc_cy: float = sill_y + sill_h * 0.5 + jamba_h
	var r_in: float = niche_w * 0.5 - 0.08
	var r_out: float = r_in + 0.20
	var r_mid: float = (r_in + r_out) * 0.5

	var shelf_pos: Vector3 = seg_center + (normal * 0.08) + Vector3(0.0, sill_y, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(niche_w + 0.24, sill_h, sill_d), Transform3D(basis, shelf_pos), 0.02)

	var jamba_w: float = 0.15
	var jamba_size := Vector3(jamba_w, jamba_h, 0.16)
	var jamba_cy: float = sill_y + sill_h * 0.5 + jamba_h * 0.5
	var left_jamba_pos := seg_center + (tangent * -r_mid) + (normal * 0.06) + Vector3(0.0, jamba_cy, 0.0)
	var right_jamba_pos := seg_center + (tangent * r_mid) + (normal * 0.06) + Vector3(0.0, jamba_cy, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, jamba_size, Transform3D(basis, left_jamba_pos), 0.02)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, jamba_size, Transform3D(basis, right_jamba_pos), 0.02)

	var impost_size := Vector3(jamba_w * 1.30, 0.08, 0.18)
	var left_impost := seg_center + (tangent * -r_mid) + (normal * 0.07) + Vector3(0.0, arc_cy, 0.0)
	var right_impost := seg_center + (tangent * r_mid) + (normal * 0.07) + Vector3(0.0, arc_cy, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, impost_size, Transform3D(basis, left_impost), 0.015)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, impost_size, Transform3D(basis, right_impost), 0.015)

	var num_dovelas: int = 11
	for k in range(num_dovelas):
		var mid_a: float = PI - (float(k) + 0.5) * (PI / float(num_dovelas))
		var dovela_px: float = cos(mid_a) * r_mid
		var dovela_py: float = arc_cy + sin(mid_a) * r_mid
		var dovela_pos: Vector3 = seg_center + (tangent * dovela_px) + (normal * 0.06) + Vector3(0.0, dovela_py, 0.0)

		var dovela_basis := basis.rotated(normal, mid_a - PI * 0.5)
		var rad_thick: float = r_out - r_in
		var tan_w: float = (r_in * (PI / float(num_dovelas))) * 1.04
		if k == 5:
			rad_thick *= 1.15
		_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(tan_w, rad_thick, 0.15), Transform3D(dovela_basis, dovela_pos), 0.015)

	var brick_rows: int = 7
	var interior_h: float = (arc_cy + r_in) - (sill_y + sill_h * 0.5)
	var row_h: float = interior_h / float(brick_rows)
	for row in range(brick_rows):
		var row_y: float = sill_y + sill_h * 0.5 + (float(row) + 0.5) * row_h
		var row_w: float = niche_w - 0.22
		if row_y > arc_cy:
			var dy: float = row_y - arc_cy
			if dy < r_in:
				var half_chord: float = sqrt(maxf(0.01, r_in * r_in - dy * dy))
				row_w = minf(row_w, half_chord * 2.0 - 0.06)
			else:
				row_w *= 0.4
		var num_bricks: int = 3 if (row % 2 == 0) else 2
		var single_bw: float = (row_w - float(num_bricks - 1) * 0.02) / float(num_bricks)
		var start_bx: float = -row_w * 0.5 + single_bw * 0.5
		for b_idx in range(num_bricks):
			var bx: float = start_bx + float(b_idx) * (single_bw + 0.02)
			var b_pos: Vector3 = seg_center + (tangent * bx) + (normal * 0.02) + Vector3(0.0, row_y, 0.0)
			_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(single_bw * 0.92, row_h * 0.78, 0.05), Transform3D(basis, b_pos), 0.01)

func _append_ornate_decoration(
	st: SurfaceTool,
	basis: Basis,
	p0: Vector3,
	p1: Vector3,
	tangent: Vector3,
	normal: Vector3,
	edge_len: float,
	bot_trim_h: float,
	panel_h: float,
	config: DecorationConfig,
	rng: RandomNumberGenerator
) -> void:
	var seg_center: Vector3 = (p0 + p1) * 0.5

	var pil_w: float = 0.22
	var pil_h: float = panel_h * 0.90
	var left_pos: Vector3 = seg_center + (tangent * (-edge_len * 0.35)) + (normal * 0.06) + Vector3(0.0, bot_trim_h + pil_h * 0.5, 0.0)
	var right_pos: Vector3 = seg_center + (tangent * (edge_len * 0.35)) + (normal * 0.06) + Vector3(0.0, bot_trim_h + pil_h * 0.5, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(pil_w, pil_h, 0.12), Transform3D(basis, left_pos), 0.02)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(pil_w, pil_h, 0.12), Transform3D(basis, right_pos), 0.02)

	var belt_pos: Vector3 = seg_center + (normal * 0.05) + Vector3(0.0, bot_trim_h + panel_h * 0.5, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(edge_len * 0.85, 0.10, 0.08), Transform3D(basis, belt_pos), 0.015)

	var crest_pos: Vector3 = seg_center + (normal * 0.08) + Vector3(0.0, bot_trim_h + panel_h * 0.72, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(0.38, 0.42, 0.10), Transform3D(basis, crest_pos), 0.02)

func _decorate_back_face_slots(
	st_bricks: SurfaceTool,
	p0: Vector3,
	tangent: Vector3,
	normal: Vector3,
	edge_len: float,
	bot_trim_h: float,
	panel_h: float,
	bw: float,
	bh: float,
	sp: float,
	w_thick: float,
	tile_size: float,
	dec_config: _DecorationConfigScript,
	noise: FastNoiseLite,
	rng: RandomNumberGenerator,
	grid: CellGrid,
	corner_pts: Array[Vector3] = [],
	excl_dist: float = 0.0
) -> bool:
	if grid == null:
		return false

	var back_tangent: Vector3 = -tangent
	var back_normal: Vector3 = -normal
	var back_basis := Basis(back_tangent, Vector3.UP, back_normal)

	var num_x_slots: int = maxi(2, int(edge_len / (bw * 1.2)))
	var num_y_slots: int = maxi(2, int(panel_h / (bh * 1.6)))
	var step_x: float = edge_len / float(num_x_slots)
	var step_y: float = panel_h / float(num_y_slots)

	var has_back_bricks: bool = false

	for iy in range(num_y_slots):
		var slot_y: float = bot_trim_h + (float(iy) * step_y) + (step_y * 0.5)

		for ix in range(num_x_slots):
			var seg_dist: float = (float(ix) * step_x) + (step_x * 0.5)
			if seg_dist < bw * 0.5 or seg_dist > edge_len - (bw * 0.5):
				continue

			var pt_world: Vector3 = p0 + (tangent * seg_dist)

			var pt_sample_back: Vector3 = pt_world - (normal * (tile_size * 0.5))
			var back_cell := Vector2i(int(floor(pt_sample_back.x / tile_size)), int(floor(pt_sample_back.z / tile_size)))
			if not grid.is_in_bounds(back_cell) or not grid.is_walkable(back_cell):
				continue

			var pt_world_back: Vector3 = pt_world - (normal * w_thick)
			var n_val: float = noise.get_noise_3d(pt_world_back.x * 1.5 + 107.0, slot_y * 2.0, pt_world_back.z * 1.5 + 107.0)
			var threshold: float = 0.65 - (dec_config.brick_density * 0.95)

			if n_val > threshold:
				var size := _get_random_brick_size(bw, bh, dec_config, rng)
				var jitter_along: float = rng.randf_range(-step_x * 0.2, step_x * 0.2)
				var jitter_y: float = rng.randf_range(-step_y * 0.15, step_y * 0.15)
				var brick_pt_back: Vector3 = pt_world_back + (tangent * jitter_along)
				if _is_near_corner(brick_pt_back, size.x * 0.5, corner_pts, excl_dist):
					continue
				var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

				_append_brick(st_bricks, back_basis, brick_pt_back, local_pos, size, dec_config, rng)
				has_back_bricks = true

				if rng.randf() < (dec_config.brick_density * 0.5):
					var size2 := _get_random_brick_size(bw * 0.85, bh, dec_config, rng)
					var pair_jitter_x: float = rng.randf_range(-bw * 0.3, bw * 0.3)
					var pair_pt_back: Vector3 = brick_pt_back + (tangent * pair_jitter_x)
					if not _is_near_corner(pair_pt_back, size2.x * 0.5, corner_pts, excl_dist):
						var pair_y: float = slot_y + jitter_y - bh - sp
						if pair_y > bot_trim_h + (bh * 0.6):
							_append_brick(st_bricks, back_basis, brick_pt_back, Vector3(pair_jitter_x, pair_y, 0.0), size2, dec_config, rng)

	return has_back_bricks
