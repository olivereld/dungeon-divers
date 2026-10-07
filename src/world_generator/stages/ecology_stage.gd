class_name EcologyStage
extends WorldStage

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var eco_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_ECOLOGY)

	var forest_noise := FastNoiseLite.new()
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest_noise.seed = eco_seed
	forest_noise.frequency = profile.get_forest_frequency()

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.seed = eco_seed + 101
	moisture_noise.frequency = profile.get_moisture_frequency()

	var region_origin: Vector2i = context.region_origin if ("region_origin" in context) else Vector2i.ZERO

	var biome_reg: RefCounted = _BiomeRegistryScript.get_default()

	for pos in context.result.cells.keys():
		var cell: WorldCell = context.result.cells[pos]
		if cell == null:
			continue
		var x: int = pos.x
		var y: int = pos.y
		var sample_x: float = float(region_origin.x + x) * profile.cell_size
		var sample_y: float = float(region_origin.y + y) * profile.cell_size
		var raw_forest := (forest_noise.get_noise_2d(sample_x, sample_y) + 1.0) * 0.5
		var raw_moisture := (moisture_noise.get_noise_2d(sample_x, sample_y) + 1.0) * 0.5

		# Resolver parámetros ecológicos desde el BiomeDefinition de la celda
		var biome_def = biome_reg.get_definition(cell.biome_id) if cell.biome_id != StringName() else null
		var eco_prof = biome_def.ecology_profile if biome_def != null else null

		var cl_thresh: float = eco_prof.clearing_threshold if eco_prof != null else profile.clearing_threshold
		var edge_width: float = eco_prof.edge_width if eco_prof != null else 0.08
		var dense_thresh: float = eco_prof.dense_forest_threshold if eco_prof != null else 0.75

		var low_bound := maxf(cl_thresh - edge_width, 0.01)
		var high_bound := minf(cl_thresh + edge_width, 0.99)

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
			if cell.forest_density > dense_thresh:
				cell.canopy_zone = WorldCell.CanopyZone.DENSE_FOREST
			else:
				cell.canopy_zone = WorldCell.CanopyZone.SPARSE_FOREST

		# Si ClimateStage ya determinó la humedad climática, preservarla; de lo contrario, calcular fallback
		if not context.result.has_meta(&"climate_stage_executed"):
			var base_moisture: float = raw_moisture
			var hydro = context.result.hydrology
			if hydro != null and hydro.has_method("is_water") and hydro.is_water(pos):
				base_moisture = clampf(base_moisture + 0.35, 0.0, 1.0)
			cell.moisture = clampf(base_moisture, 0.0, 1.0)
