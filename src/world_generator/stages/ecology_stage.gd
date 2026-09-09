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
			var raw_forest := (forest_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var raw_moisture := (moisture_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5

			# Clearings appear where forest noise dips below threshold
			if raw_forest < profile.clearing_threshold:
				cell.clearing_density = 1.0 - (raw_forest / profile.clearing_threshold)
				cell.forest_density = 0.0
			else:
				cell.clearing_density = 0.0
				cell.forest_density = (raw_forest - profile.clearing_threshold) / (1.0 - profile.clearing_threshold)

			cell.moisture = clampf(raw_moisture, 0.0, 1.0)
