class_name FoliageGenerator
extends RefCounted

## Generador procedural desacoplado de follaje (césped, hierbas, flores) en worker threads.
## Totalmente determinista, basado en coordenadas de mundo, libre de raycasts y dependencias de SceneTree.

const _FoliageChunkDataScript = preload("res://src/world_generator/foliage/foliage_chunk_data.gd")
const _FoliageProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _NavigationStageScript = preload("res://src/world_generator/stages/navigation_stage.gd")
func evaluate_ecological_zone(cell: WorldCell, large_noise_val: float = 0.5) -> int:
	if cell == null:
		return _FoliageProfileScript.EcologicalZone.PLAINS
	if cell.clearing_density > 0.65 or cell.forest_density < 0.08:
		return _FoliageProfileScript.EcologicalZone.PLAINS if cell.forest_density < 0.05 else _FoliageProfileScript.EcologicalZone.CLEARING
	elif cell.forest_density > 0.60 and cell.clearing_density < 0.20:
		return _FoliageProfileScript.EcologicalZone.DENSE_FOREST
	elif cell.forest_density > 0.30:
		return _FoliageProfileScript.EcologicalZone.OPEN_FOREST
	else:
		return _FoliageProfileScript.EcologicalZone.FOREST_EDGE

func evaluate_patch_coverage_at(pos: Vector2i, master_seed: int, profile: FoliageProfile) -> float:
	var l_freq: float = profile.large_noise_frequency if (profile != null and profile.large_noise_frequency > 0.0) else 0.02
	var f_freq: float = profile.fine_noise_frequency if (profile != null and profile.fine_noise_frequency > 0.0) else 0.12

	var l_noise := FastNoiseLite.new()
	l_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	l_noise.seed = (master_seed ^ 0x3F5A) & 0x7FFFFFFF
	l_noise.frequency = l_freq

	var f_noise := FastNoiseLite.new()
	f_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f_noise.seed = (master_seed ^ 0x9B1C) & 0x7FFFFFFF
	f_noise.frequency = f_freq

	var val_l: float = (l_noise.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5
	var val_f: float = (f_noise.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5
	return clampf(val_l * 0.65 + val_f * 0.35, 0.0, 1.0)

func sample_weighted_scale(species: FoliageSpecies, rng: RandomNumberGenerator, zone_id: int = 0) -> Vector3:
	if species == null:
		return Vector3.ONE

	var weights: Dictionary = species.scale_weights if (species.scale_weights != null and not species.scale_weights.is_empty()) else {"small": 0.70, "medium": 0.25, "large": 0.05}
	var w_small: float = float(weights.get("small", 0.70))
	var w_med: float = float(weights.get("medium", 0.25))
	var w_large: float = float(weights.get("large", 0.05))
	var total_w: float = maxf(0.001, w_small + w_med + w_large)

	var roll: float = rng.randf() * total_w
	var sc_mult: float = 1.0

	var r_small: Vector2 = species.small_mult_range if species.small_mult_range != Vector2.ZERO else Vector2(0.75, 0.95)
	var r_med: Vector2 = species.medium_mult_range if species.medium_mult_range != Vector2.ZERO else Vector2(0.95, 1.15)
	var r_large: Vector2 = species.large_mult_range if species.large_mult_range != Vector2.ZERO else Vector2(1.15, 1.35)

	if roll < w_small:
		sc_mult = rng.randf_range(r_small.x, r_small.y)
	elif roll < w_small + w_med:
		sc_mult = rng.randf_range(r_med.x, r_med.y)
	else:
		sc_mult = rng.randf_range(r_large.x, r_large.y)

	var zone_mult: float = 1.0
	if zone_id == _FoliageProfileScript.EcologicalZone.PLAINS or zone_id == _FoliageProfileScript.EcologicalZone.CLEARING:
		zone_mult = rng.randf_range(0.95, 1.18)
	elif zone_id == _FoliageProfileScript.EcologicalZone.DENSE_FOREST:
		zone_mult = rng.randf_range(0.75, 0.95)
	elif zone_id == _FoliageProfileScript.EcologicalZone.OPEN_FOREST:
		zone_mult = rng.randf_range(0.85, 1.05)

	var base_sc_x: float = rng.randf_range(species.scale_min.x, species.scale_max.x)
	var base_sc_y: float = rng.randf_range(species.scale_min.y, species.scale_max.y)
	var base_sc_z: float = rng.randf_range(species.scale_min.z, species.scale_max.z)

	return Vector3(
		base_sc_x * sc_mult * zone_mult,
		base_sc_y * sc_mult * zone_mult,
		base_sc_z * sc_mult * zone_mult
	)

func compute_canopy_attenuation(cell: WorldCell, nearby_trees_density: float, profile: FoliageProfile) -> float:
	var atten_floor: float = profile.canopy_attenuation_factor if profile != null else 0.35
	var tree_factor: float = nearby_trees_density
	if cell != null:
		tree_factor = maxf(tree_factor, cell.forest_density)
	return clampf(1.0 - (tree_factor * (1.0 - atten_floor)), atten_floor, 1.0)

func compute_species_effective_weight(
	species: FoliageSpecies,
	profile: FoliageProfile,
	zone_id: int,
	forest_density: float,
	in_clump: bool = true
) -> float:
	if species == null or profile == null:
		return 0.0
	var base_w: float = maxf(species.density_weight, 0.01)
	var zone_dict: Dictionary = profile.zone_densities.get(zone_id, {})

	match species.foliage_type:
		_FoliageSpeciesScript.FoliageType.MUSHROOM:
			if not in_clump:
				return 0.0
			var zone_mult: float = float(zone_dict.get("mushroom", 0.50))
			var shade_factor: float = clampf(0.20 + forest_density * 1.60, 0.15, 2.0)
			return base_w * zone_mult * shade_factor * 3.5
		_FoliageSpeciesScript.FoliageType.FLOWER:
			if not in_clump:
				return 0.0
			var zone_mult: float = float(zone_dict.get("flower", 0.80))
			var sun_factor: float = clampf(1.30 - forest_density * 1.10, 0.10, 1.5)
			return base_w * zone_mult * sun_factor * 3.0
		_: # GRASS
			var zone_mult: float = float(zone_dict.get("grass", 1.0))
			return base_w * zone_mult

func generate_foliage(
	result: WorldResult,
	master_seed: int,
	bounds: Rect2i,
	profile: WorldProfile = null,
	registry: RefCounted = null
) -> RefCounted:
	var foliage_data := _FoliageChunkDataScript.new(bounds.position)
	if result == null:
		return foliage_data

	var biome_reg = registry if registry != null else _BiomeRegistryScript.get_default()
	var fol_seed: int = int(("%d:foliage" % master_seed).hash()) & 0x7FFFFFFF

	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.seed = fol_seed
	macro_noise.frequency = 0.08

	var mush_clump_noise := FastNoiseLite.new()
	mush_clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mush_clump_noise.seed = (fol_seed ^ 0x5A8E) & 0x7FFFFFFF
	mush_clump_noise.frequency = 0.14

	var flower_clump_noise := FastNoiseLite.new()
	flower_clump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	flower_clump_noise.seed = (fol_seed ^ 0x3D71) & 0x7FFFFFFF
	flower_clump_noise.frequency = 0.11

	var hydro = result.hydrology
	var rng := RandomNumberGenerator.new()

	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var pos := Vector2i(x, y)
			var cell: WorldCell = result.get_cell(pos)
			if cell == null:
				continue

			# 1. Filtro rápido de autoridad hidrológica (sin hierba terrestre en agua)
			if hydro != null:
				if hydro.has_method("is_water") and hydro.is_water(pos):
					continue
				if hydro.has_method("is_vegetation_excluded") and hydro.is_vegetation_excluded(pos):
					continue

			# 2. Filtro de acantilados verticales
			if cell.slope_category == NavigationStage.SlopeCategory.CLIFF:
				continue

			# 3. Resolver bioma y foliage_profile
			var biome_def = biome_reg.get_definition(cell.biome_id) if cell.biome_id != StringName() else null
			var fol_prof = biome_def.foliage_profile if (biome_def != null and biome_def.foliage_profile != null) else (profile.foliage_profile if profile != null else null)
			if fol_prof == null:
				continue

			var species_list: Array = fol_prof.species
			if species_list.is_empty():
				continue

			# 4. Filtro de pendiente máxima del perfil del bioma
			if cell.slope > fol_prof.max_slope:
				continue

			# 5. Sistema de Cobertura Ecológica de Parches y Clasificación de Zona
			var patch_cov: float = evaluate_patch_coverage_at(pos, master_seed, fol_prof)
			var slope_factor: float = clampf(1.0 - (cell.slope / maxf(fol_prof.max_slope, 1.0)), 0.0, 1.0)
			var zone_id: int = evaluate_ecological_zone(cell)
			var canopy_atten: float = compute_canopy_attenuation(cell, 0.0, fol_prof)

			var zone_mult: float = 1.0
			if fol_prof.zone_densities != null and fol_prof.zone_densities.has(zone_id):
				zone_mult = float(fol_prof.zone_densities[zone_id].get("grass", 1.0))

			# Umbral de claros limpios aplicado sobre la señal de parches
			var clear_thresh: float = fol_prof.clearing_threshold if fol_prof.clearing_threshold > 0.0 else 0.25
			if patch_cov < clear_thresh:
				continue

			# Densidad modulada por bioma, zona ecológica, dosel arbóreo y pendiente
			var norm_cov: float = clampf((patch_cov - clear_thresh) / maxf(1.0 - clear_thresh, 0.01), 0.0, 1.0)
			var target_density: float = (1.5 + norm_cov * 4.5) * fol_prof.base_density * canopy_atten * zone_mult * slope_factor
			if target_density < 0.25:
				continue

			var base_count: int = maxi(1, int(floor(target_density)))
			var remainder: float = fmod(target_density, 1.0)

			# Evaluación de racimos/clumps ecológicos para hongos y flores
			var in_mush_clump: bool = cell.forest_density >= 0.20 and mush_clump_noise.get_noise_2d(float(x), float(y)) > 0.18
			var in_flower_clump: bool = cell.forest_density <= 0.35 and flower_clump_noise.get_noise_2d(float(x), float(y)) > 0.20

			# Sumar pesos de especies modulados ecológicamente por hábitat y agrupamiento en racimos
			var total_weight: float = 0.0
			for sp in species_list:
				if sp != null:
					var is_clumped: bool = true
					if sp.foliage_type == _FoliageSpeciesScript.FoliageType.MUSHROOM:
						is_clumped = in_mush_clump
					elif sp.foliage_type == _FoliageSpeciesScript.FoliageType.FLOWER:
						is_clumped = in_flower_clump
					total_weight += compute_species_effective_weight(sp, fol_prof, zone_id, cell.forest_density, is_clumped)

			if total_weight <= 0.0001:
				continue

			# Determinar cantidad determinista de briznas para la celda
			var cell_hash: int = ((fol_seed * 73856093) ^ (x * 19349663) ^ (y * 83492791)) & 0x7FFFFFFF
			rng.seed = cell_hash

			var blade_count := base_count
			if rng.randf() < remainder:
				blade_count += 1

			for k in range(blade_count):
				# Selección de especie por ruleta de peso ecológico
				var roll := rng.randf() * total_weight
				var accumulated := 0.0
				var chosen_species = species_list[0]
				for sp in species_list:
					if sp != null:
						var is_clumped: bool = true
						if sp.foliage_type == _FoliageSpeciesScript.FoliageType.MUSHROOM:
							is_clumped = in_mush_clump
						elif sp.foliage_type == _FoliageSpeciesScript.FoliageType.FLOWER:
							is_clumped = in_flower_clump
						accumulated += compute_species_effective_weight(sp, fol_prof, zone_id, cell.forest_density, is_clumped)
						if roll <= accumulated:
							chosen_species = sp
							break

				if chosen_species == null:
					continue

				if cell.slope > chosen_species.max_slope:
					continue

				# Jitter sub-celda compacto para agrupar briznas en un mechón con cuerpo
				var jx := (rng.randf() - 0.5) * 0.75
				var jz := (rng.randf() - 0.5) * 0.75
				var world_x := float(x) + 0.5 + jx
				var world_z := float(y) + 0.5 + jz
				var world_y := cell.height

				var rot_y := rng.randf_range(0.0, TAU)
				var scale: Vector3 = sample_weighted_scale(chosen_species, rng, zone_id)

				var tr := Transform3D()
				tr.basis = Basis(Vector3.UP, rot_y).scaled(scale)
				tr.origin = Vector3(world_x, world_y, world_z)

				# Variación de tinte sutil por brizna armonizada con la paleta de terreno del perfil
				var tint_val := rng.randf_range(0.95, 1.05)
				var color := Color(tint_val, tint_val, tint_val, 1.0)
				var should_tint: bool = chosen_species.tint_with_grass_color if ("tint_with_grass_color" in chosen_species) else true
				if should_tint and profile != null and "terrain_grass_color" in profile:
					var g_col: Color = profile.terrain_grass_color
					var max_g := maxf(g_col.r, maxf(g_col.g, g_col.b))
					if max_g > 0.01:
						var norm_g := Color(g_col.r / max_g, g_col.g / max_g, g_col.b / max_g, 1.0)
						color = color.lerp(norm_g * tint_val, 0.15)

				foliage_data.add_instance(chosen_species.id, tr, color)

	return foliage_data
