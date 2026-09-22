class_name TerrainStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var terrain_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_TERRAIN)

	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.seed = terrain_seed
	macro_noise.frequency = profile.get_macro_frequency()

	var medium_noise := FastNoiseLite.new()
	medium_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medium_noise.seed = terrain_seed + 101
	medium_noise.frequency = profile.get_medium_frequency()

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = terrain_seed + 202
	detail_noise.frequency = profile.get_detail_frequency()

	var warp_noise_x := FastNoiseLite.new()
	var warp_noise_y := FastNoiseLite.new()
	if profile.warp_enabled:
		warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_x.seed = terrain_seed + 303
		warp_noise_x.frequency = profile.get_warp_frequency()
		warp_noise_x.fractal_octaves = profile.warp_octaves

		warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_y.seed = terrain_seed + 404
		warp_noise_y.frequency = profile.get_warp_frequency()
		warp_noise_y.fractal_octaves = profile.warp_octaves

	var a_macro: float = profile.get_macro_amplitude()
	var a_med: float = profile.get_medium_amplitude()
	var a_det: float = profile.get_detail_amplitude()
	var shape_amplitude: float = a_macro + a_med
	if shape_amplitude <= 0.0:
		shape_amplitude = 1.0

	var warp_amp: float = profile.get_warp_amplitude()

	var gen_bounds: Rect2i = context.get_generation_bounds() if context.has_method("get_generation_bounds") else Rect2i(0, 0, profile.width, profile.height)
	var core_bounds: Rect2i = context.get_core_bounds() if context.has_method("get_core_bounds") else gen_bounds

	var region_origin: Vector2i = context.region_origin if ("region_origin" in context) else Vector2i.ZERO

	# 1. Height computation across generation bounds (core + halo)
	for y in range(gen_bounds.position.y, gen_bounds.end.y):
		for x in range(gen_bounds.position.x, gen_bounds.end.x):
			var sample_x: float = float(region_origin.x + x) * profile.cell_size
			var sample_y: float = float(region_origin.y + y) * profile.cell_size

			if profile.warp_enabled:
				var wx := warp_noise_x.get_noise_2d(sample_x, sample_y) * warp_amp
				var wy := warp_noise_y.get_noise_2d(sample_x, sample_y) * warp_amp
				sample_x += wx
				sample_y += wy

			var n_macro := macro_noise.get_noise_2d(sample_x, sample_y)
			var n_med := medium_noise.get_noise_2d(sample_x, sample_y)
			# detail_noise permanece para usos posteriores, pero no interviene en la forma de las terrazas
			# Weighted symmetric composition in [-1.0, 1.0] from MACRO + MEDIUM
			var composite := (n_macro * a_macro + n_med * a_med) / shape_amplitude
			# Map to normalized [0.0, 1.0] space
			var norm_val := clampf((composite + 1.0) * 0.5, 0.0, 1.0)
			# Non-linear relief shaping
			var shaped := pow(norm_val, profile.relief_exponent)

			var normalized_terrain: float = shaped
			var level_count: int = max(profile.elevation_level_count, 1)
			var raw_level: int = int(floor(normalized_terrain * float(level_count)))
			var min_lvl: int = profile.elevation_min_level
			var max_lvl: int = profile.elevation_max_level if profile.elevation_max_level >= min_lvl else (level_count - 1)
			var level: int = clampi(raw_level, min_lvl, max_lvl)

			var total_range: float = float(level_count) * profile.elevation_step_height
			var raw_h: float = profile.base_height + (normalized_terrain * total_range)
			var final_h: float = profile.base_height + float(level) * profile.elevation_step_height

			var cell: WorldCell = context.result.get_cell(Vector2i(x, y))
			if cell != null:
				cell.raw_height = raw_h
				cell.elevation_level = level
				cell.height = final_h

	# 2. Normalization & Slope computation (Stepped Terrain Contract)
	var min_lvl: int = profile.elevation_min_level
	var max_lvl: int = profile.elevation_max_level if profile.elevation_max_level > min_lvl else max(profile.elevation_level_count - 1, 1)
	var lvl_span: float = float(max(max_lvl - min_lvl, 1))

	var is_chunk: bool = context.has_method("is_chunk_context") and context.is_chunk_context()
	var is_bounded: bool = profile != null and profile.width > 0 and profile.height > 0
	if is_chunk and "config" in context and context.config != null and context.config.is_unbounded:
		is_bounded = false

	for pos in context.result.cells.keys():
		var cell: WorldCell = context.result.cells[pos]
		if cell == null:
			continue
		var x: int = pos.x
		var y: int = pos.y

		# Altura normalizada derivada directamente de la autoridad discreta [0.0, 1.0]
		cell.normalized_height = clampf(float(cell.elevation_level - min_lvl) / lvl_span, 0.0, 1.0)

		# Slope escalonado: same level -> 0.0° (plano/plateau), different level -> 90.0° (cliff vertical)
		var clamp_left: bool = is_bounded and (x == 0 if is_chunk else x <= 0)
		var clamp_right: bool = is_bounded and (x == profile.width - 1 if is_chunk else x >= profile.width - 1)
		var clamp_up: bool = is_bounded and (y == 0 if is_chunk else y <= 0)
		var clamp_down: bool = is_bounded and (y == profile.height - 1 if is_chunk else y >= profile.height - 1)

		var cell_left: WorldCell = null if clamp_left else context.result.get_cell(Vector2i(x - 1, y))
		var cell_right: WorldCell = null if clamp_right else context.result.get_cell(Vector2i(x + 1, y))
		var cell_up: WorldCell = null if clamp_up else context.result.get_cell(Vector2i(x, y - 1))
		var cell_down: WorldCell = null if clamp_down else context.result.get_cell(Vector2i(x, y + 1))

		var is_cliff := false
		if cell_left != null and cell_left.elevation_level != cell.elevation_level:
			is_cliff = true
		elif cell_right != null and cell_right.elevation_level != cell.elevation_level:
			is_cliff = true
		elif cell_up != null and cell_up.elevation_level != cell.elevation_level:
			is_cliff = true
		elif cell_down != null and cell_down.elevation_level != cell.elevation_level:
			is_cliff = true

		cell.slope = 90.0 if is_cliff else 0.0

		var expected_h := profile.base_height + float(cell.elevation_level) * profile.elevation_step_height
		assert(is_equal_approx(cell.height, expected_h), "TerrainStage invariant violated: height != base + level * step at %s" % str(cell.position))
		assert(cell.elevation_level >= profile.elevation_min_level and cell.elevation_level <= profile.max_elevation_level, "TerrainStage invariant violated: elevation_level out of bounds at %s" % str(cell.position))

