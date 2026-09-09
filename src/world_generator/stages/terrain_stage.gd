class_name TerrainStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var terrain_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_TERRAIN)

	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.seed = terrain_seed
	macro_noise.frequency = profile.macro_frequency

	var medium_noise := FastNoiseLite.new()
	medium_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medium_noise.seed = terrain_seed + 101
	medium_noise.frequency = profile.medium_frequency

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = terrain_seed + 202
	detail_noise.frequency = profile.detail_frequency

	var warp_noise_x := FastNoiseLite.new()
	var warp_noise_y := FastNoiseLite.new()
	if profile.warp_enabled:
		warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_x.seed = terrain_seed + 303
		warp_noise_x.frequency = profile.warp_frequency
		warp_noise_x.fractal_octaves = profile.warp_octaves

		warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_y.seed = terrain_seed + 404
		warp_noise_y.frequency = profile.warp_frequency
		warp_noise_y.fractal_octaves = profile.warp_octaves

	var total_noise_weight := profile.macro_strength + profile.medium_strength + profile.detail_strength
	if total_noise_weight <= 0.0:
		total_noise_weight = 1.0

	var min_h := INF
	var max_h := -INF

	# 1. Height computation
	for y in range(profile.height):
		for x in range(profile.width):
			var sample_x: float = float(x) * profile.cell_size
			var sample_y: float = float(y) * profile.cell_size

			if profile.warp_enabled:
				var wx := warp_noise_x.get_noise_2d(sample_x, sample_y) * profile.warp_strength
				var wy := warp_noise_y.get_noise_2d(sample_x, sample_y) * profile.warp_strength
				sample_x += wx
				sample_y += wy

			var n_macro := macro_noise.get_noise_2d(sample_x, sample_y)
			var n_med := medium_noise.get_noise_2d(sample_x, sample_y)
			var n_det := detail_noise.get_noise_2d(sample_x, sample_y)

			# Weighted symmetric composition in [-1.0, 1.0]
			var composite := (n_macro * profile.macro_strength + n_med * profile.medium_strength + n_det * profile.detail_strength) / total_noise_weight
			# Map to normalized [0.0, 1.0] space
			var norm_val := clampf((composite + 1.0) * 0.5, 0.0, 1.0)
			# Non-linear relief shaping
			var shaped := pow(norm_val, profile.relief_exponent)

			var h: float = profile.base_height + (shaped * total_noise_weight * profile.height_scale)
			if h < min_h: min_h = h
			if h > max_h: max_h = h

			var cell := context.result.get_cell(Vector2i(x, y))
			cell.height = h

	# 2. Normalization & Slope computation
	var h_range := maxf(max_h - min_h, 0.001)
	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))
			cell.normalized_height = (cell.height - min_h) / h_range

			# Central differences for slope
			var h_left: float = context.result.get_cell(Vector2i(maxi(x - 1, 0), y)).height
			var h_right: float = context.result.get_cell(Vector2i(mini(x + 1, profile.width - 1), y)).height
			var h_up: float = context.result.get_cell(Vector2i(x, maxi(y - 1, 0))).height
			var h_down: float = context.result.get_cell(Vector2i(x, mini(y + 1, profile.height - 1))).height

			var dx := (h_right - h_left) / (2.0 * profile.cell_size)
			var dy := (h_down - h_up) / (2.0 * profile.cell_size)
			var gradient := sqrt(dx * dx + dy * dy)
			cell.slope = rad_to_deg(atan(gradient))
