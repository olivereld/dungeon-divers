class_name FoliageGenerator
extends RefCounted

## Generador procedural desacoplado de follaje (césped, hierbas, flores) en worker threads.
## Totalmente determinista, basado en coordenadas de mundo, libre de raycasts y dependencias de SceneTree.

const _FoliageChunkDataScript = preload("res://src/world_generator/foliage/foliage_chunk_data.gd")
const _FoliageProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _NavigationStageScript = preload("res://src/world_generator/stages/navigation_stage.gd")

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
			if biome_def == null or biome_def.foliage_profile == null:
				continue

			var fol_prof = biome_def.foliage_profile
			var species_list: Array = fol_prof.species
			if species_list.is_empty():
				continue

			# 4. Filtro de pendiente máxima del perfil del bioma
			if cell.slope > fol_prof.max_slope:
				continue

			# 5. Sistema de Coverage Continuo y Clustering:
			# Combina el ruido macro de parches con atenuación por pendiente y densidad del bioma
			var noise_val: float = (macro_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var slope_factor: float = clampf(1.0 - (cell.slope / maxf(fol_prof.max_slope, 1.0)), 0.0, 1.0)
			var coverage: float = noise_val * slope_factor * fol_prof.base_density

			# Umbral de claros limpios: por debajo de 0.28 el suelo permanece limpio (senderos/claros naturales)
			if coverage < 0.28:
				continue

			# Si la celda tiene vegetación, genera un mechón con cuerpo (mínimo 3 briznas, hasta 7 en zonas densas)
			var norm_cov: float = clampf((coverage - 0.28) / 0.72, 0.0, 1.0)
			var target_density: float = 3.0 + norm_cov * 4.0
			var base_count: int = int(floor(target_density))
			var remainder: float = fmod(target_density, 1.0)

			# Sumar pesos de especies
			var total_weight: float = 0.0
			for sp in species_list:
				if sp != null and "density_weight" in sp:
					total_weight += maxf(sp.density_weight, 0.01)

			if total_weight <= 0.0001:
				continue

			# Determinar cantidad determinista de briznas para la celda
			var cell_hash: int = ((fol_seed * 73856093) ^ (x * 19349663) ^ (y * 83492791)) & 0x7FFFFFFF
			rng.seed = cell_hash

			var blade_count := base_count
			if rng.randf() < remainder:
				blade_count += 1

			for k in range(blade_count):
				# Selección de especie por ruleta de peso
				var roll := rng.randf() * total_weight
				var accumulated := 0.0
				var chosen_species = species_list[0]
				for sp in species_list:
					if sp != null:
						accumulated += sp.density_weight
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
				var is_single: bool = (chosen_species.id == &"grass_single" or String(chosen_species.id).ends_with("_single"))
				var sc_mult: float = rng.randf_range(0.85, 1.15) if is_single else rng.randf_range(0.95, 1.30)
				# Aumento de grosor horizontal para dar volumen a las matas de hierba media y grande
				var horiz_boost: float = 1.0 if is_single else rng.randf_range(1.25, 1.45)
				var scale := Vector3(
					rng.randf_range(chosen_species.scale_min.x, chosen_species.scale_max.x) * sc_mult * horiz_boost,
					rng.randf_range(chosen_species.scale_min.y, chosen_species.scale_max.y) * sc_mult,
					rng.randf_range(chosen_species.scale_min.z, chosen_species.scale_max.z) * sc_mult * horiz_boost
				)

				var tr := Transform3D()
				tr.basis = Basis(Vector3.UP, rot_y).scaled(scale)
				tr.origin = Vector3(world_x, world_y, world_z)

				# Variación de tinte sutil por brizna armonizada con la paleta de terreno del perfil
				var tint_val := rng.randf_range(0.94, 1.06)
				var color := Color(tint_val, tint_val, tint_val, 1.0)
				if profile != null and "terrain_grass_color" in profile:
					var g_col: Color = profile.terrain_grass_color
					var max_g := maxf(g_col.r, maxf(g_col.g, g_col.b))
					if max_g > 0.01:
						var norm_g := Color(g_col.r / max_g, g_col.g / max_g, g_col.b / max_g, 1.0)
						color = color.lerp(norm_g * tint_val, 0.15)

				foliage_data.add_instance(chosen_species.id, tr, color)

	return foliage_data
