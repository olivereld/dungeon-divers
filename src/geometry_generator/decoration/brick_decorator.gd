class_name BrickDecorator
extends RefCounted

## Decorador superficial procedimental de ladrillos estilizados en relieve (Fase M4).
## Añade la superficie de ladrillos (Bricks) a un GeneratedMesh sin mutar la topología estructural base.

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
	dec_config: _DecorationConfigScript
) -> void:
	if g_mesh == null or g_mesh.mesh == null or section == null or dec_config == null or section.points.size() < 2:
		return

	if not dec_config.enabled or dec_config.style == _DecorationConfigScript.DecorationStyle.NONE:
		return

	if geom_config == null:
		geom_config = _WallGeometryConfigScript.new()

	var tile_size: float = geom_config.cube_size
	var panel_h: float = geom_config.get_wall_panel_height()
	var bot_trim_h: float = geom_config.bottom_trim_height

	var noise := FastNoiseLite.new()
	noise.seed = dec_config.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = dec_config.noise_frequency

	var rng := RandomNumberGenerator.new()
	rng.seed = dec_config.seed + section.id * 17

	var st_bricks := SurfaceTool.new()
	st_bricks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bw: float = dec_config.brick_width
	var bh: float = dec_config.brick_height
	var sp: float = 0.022
	var has_bricks: bool = false

	var pts_count: int = section.points.size()
	var seg_count: int = pts_count if section.is_closed_loop else (pts_count - 1)

	var is_niche: bool = (section.variant_id == &"niche" or section.variant_id == &"niche_alcove")
	var is_ornate: bool = (section.variant_id == &"ornate")

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

			# Generar ladrillos sutiles y moderados en los paños de muro alrededor del nicho (sin saturar)
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
					# Evitar el área ocupada por el nicho
					if dist_from_mid < niche_half_w and slot_y < niche_max_y:
						continue
					if seg_dist < bw * 0.5 or seg_dist > edge_len - (bw * 0.5):
						continue

					var pt_world: Vector3 = p0 + (tangent * seg_dist)
					var n_val: float = noise.get_noise_3d(pt_world.x * 1.5, slot_y * 2.0, pt_world.z * 1.5)
					# Densidad moderada y natural (no exagerada)
					if n_val > 0.22:
						var size := _get_random_brick_size(bw * 0.88, bh * 0.95, dec_config, rng)
						var jitter_along: float = rng.randf_range(-step_x * 0.15, step_x * 0.15)
						var jitter_y: float = rng.randf_range(-step_y * 0.10, step_y * 0.10)
						var brick_pt: Vector3 = pt_world + (tangent * jitter_along)
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)
						_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
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
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

						_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						has_bricks = true

						if rng.randf() < (dec_config.brick_density * 0.5):
							var size2 := _get_random_brick_size(bw * 0.85, bh, dec_config, rng)
							var pair_y: float = slot_y + jitter_y - bh - sp
							if pair_y > bot_trim_h + (bh * 0.6):
								_append_brick(st_bricks, basis, brick_pt, Vector3(rng.randf_range(-bw * 0.3, bw * 0.3), pair_y, 0.0), size2, dec_config, rng)

	if has_bricks:
		st_bricks.generate_normals()
		st_bricks.index()
		st_bricks.generate_tangents()
		g_mesh.mesh = st_bricks.commit(g_mesh.mesh)
		var surf_idx: int = g_mesh.mesh.get_surface_count() - 1
		g_mesh.mesh.surface_set_name(surf_idx, "Bricks")

func decorate_component(
	g_mesh: GeneratedMesh,
	component: WallComponent,
	geom_config: WallGeometryConfig,
	dec_config: DecorationConfig
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
			var normal: Vector3 = Vector3(-tangent.z, 0.0, tangent.x) # Hacia el espacio abierto
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
						var local_pos := Vector3(0.0, slot_y + jitter_y, 0.0)

						_append_brick(st_bricks, basis, brick_pt, local_pos, size, dec_config, rng)
						has_bricks = true

						if rng.randf() < (dec_config.brick_density * 0.5):
							var size2 := _get_random_brick_size(bw * 0.85, bh, dec_config, rng)
							var pair_y: float = slot_y + jitter_y - bh - sp
							if pair_y > bot_trim_h + (bh * 0.6):
								_append_brick(st_bricks, basis, brick_pt, Vector3(rng.randf_range(-bw * 0.3, bw * 0.3), pair_y, 0.0), size2, dec_config, rng)

	if has_bricks:
		st_bricks.generate_normals()
		st_bricks.index()
		st_bricks.generate_tangents()
		g_mesh.mesh = st_bricks.commit(g_mesh.mesh)
		var surf_idx: int = g_mesh.mesh.get_surface_count() - 1
		g_mesh.mesh.surface_set_name(surf_idx, "Bricks")

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

	# 1. Repisa de piedra saliente
	var shelf_pos: Vector3 = seg_center + (normal * 0.08) + Vector3(0.0, sill_y, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(niche_w + 0.24, sill_h, sill_d), Transform3D(basis, shelf_pos), 0.02)

	# 2. Jambas verticales de enmarcado a los lados con capitel de arranque
	var jamba_w: float = 0.15
	var jamba_size := Vector3(jamba_w, jamba_h, 0.16)
	var jamba_cy: float = sill_y + sill_h * 0.5 + jamba_h * 0.5
	var left_jamba_pos := seg_center + (tangent * -r_mid) + (normal * 0.06) + Vector3(0.0, jamba_cy, 0.0)
	var right_jamba_pos := seg_center + (tangent * r_mid) + (normal * 0.06) + Vector3(0.0, jamba_cy, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, jamba_size, Transform3D(basis, left_jamba_pos), 0.02)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, jamba_size, Transform3D(basis, right_jamba_pos), 0.02)

	# Bloques de imposta/capitel que sellan la unión entre jamba vertical y dovela arqueada
	var impost_size := Vector3(jamba_w * 1.30, 0.08, 0.18)
	var left_impost := seg_center + (tangent * -r_mid) + (normal * 0.07) + Vector3(0.0, arc_cy, 0.0)
	var right_impost := seg_center + (tangent * r_mid) + (normal * 0.07) + Vector3(0.0, arc_cy, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, impost_size, Transform3D(basis, left_impost), 0.015)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, impost_size, Transform3D(basis, right_impost), 0.015)

	# 3. Arco de dovelas radiales de piedra (11 dovelas en abanico continuo)
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

	# 4. Hiladas de ladrillos en relieve dentro del nicho
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

	# 1. Pilastras laterales en relieve
	var pil_w: float = 0.22
	var pil_h: float = panel_h * 0.90
	var left_pos: Vector3 = seg_center + (tangent * (-edge_len * 0.35)) + (normal * 0.06) + Vector3(0.0, bot_trim_h + pil_h * 0.5, 0.0)
	var right_pos: Vector3 = seg_center + (tangent * (edge_len * 0.35)) + (normal * 0.06) + Vector3(0.0, bot_trim_h + pil_h * 0.5, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(pil_w, pil_h, 0.12), Transform3D(basis, left_pos), 0.02)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(pil_w, pil_h, 0.12), Transform3D(basis, right_pos), 0.02)

	# 2. Moldura horizontal central (faja)
	var belt_pos: Vector3 = seg_center + (normal * 0.05) + Vector3(0.0, bot_trim_h + panel_h * 0.5, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(edge_len * 0.85, 0.10, 0.08), Transform3D(basis, belt_pos), 0.015)

	# 3. Escudo / Relieve heráldico en el centro superior
	var crest_pos: Vector3 = seg_center + (normal * 0.08) + Vector3(0.0, bot_trim_h + panel_h * 0.72, 0.0)
	_BrickGeometryBuilderScript.append_pillowed_brick(st, Vector3(0.38, 0.42, 0.10), Transform3D(basis, crest_pos), 0.02)
