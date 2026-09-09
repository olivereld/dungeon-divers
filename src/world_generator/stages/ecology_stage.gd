class_name EcologyStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var eco_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_ECOLOGY)

	var forest_noise := FastNoiseLite.new()
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest_noise.seed = eco_seed
	forest_noise.frequency = profile.forest_frequency

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.seed = eco_seed + 101
	moisture_noise.frequency = profile.moisture_frequency

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))
			var sample_x: float = float(x) * profile.cell_size
			var sample_y: float = float(y) * profile.cell_size
			var raw_forest := (forest_noise.get_noise_2d(sample_x, sample_y) + 1.0) * 0.5
			var raw_moisture := (moisture_noise.get_noise_2d(sample_x, sample_y) + 1.0) * 0.5

			var edge_width: float = 0.08
			var low_bound := maxf(profile.clearing_threshold - edge_width, 0.01)
			var high_bound := minf(profile.clearing_threshold + edge_width, 0.99)

			if raw_forest <= low_bound:
				cell.clearing_density = clampf(1.0 - (raw_forest / low_bound), 0.0, 1.0)
				cell.forest_density = 0.0
				cell.canopy_zone = WorldCell.CanopyZone.CLEARING
			elif raw_forest < high_bound:
				var t := (raw_forest - low_bound) / (high_bound - low_bound)
				var smooth_t := smoothstep(0.0, 1.0, t)
				cell.forest_density = clampf(smooth_t * 0.4, 0.0, 1.0)
				cell.clearing_density = clampf((1.0 - smooth_t) * 0.5, 0.0, 1.0)
				cell.canopy_zone = WorldCell.CanopyZone.FOREST_EDGE
			else:
				var f_ratio := (raw_forest - high_bound) / maxf(1.0 - high_bound, 0.001)
				cell.clearing_density = 0.0
				cell.forest_density = clampf(0.4 + 0.6 * f_ratio, 0.0, 1.0)
				if cell.forest_density > 0.75:
					cell.canopy_zone = WorldCell.CanopyZone.DENSE_FOREST
				else:
					cell.canopy_zone = WorldCell.CanopyZone.SPARSE_FOREST

			var pos := Vector2i(x, y)
			var base_moisture: float = raw_moisture

			# Riparian boost near lakes and rivers
			var hydro = context.result.hydrology
			if hydro != null and hydro.has_method("is_water") and hydro.is_water(pos):
				base_moisture = clampf(base_moisture + 0.35, 0.0, 1.0)

			cell.moisture = clampf(base_moisture, 0.0, 1.0)
