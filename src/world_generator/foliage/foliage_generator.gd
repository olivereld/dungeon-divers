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

			# 5. Muestreo de ruido macro espacial para parches naturales de claros
			var noise_val: float = (macro_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			if noise_val < 0.20:
				continue # Claro natural sin césped denso

			# Densidad efectiva en la celda
			var effective_density: float = fol_prof.base_density * noise_val
			var base_count: int = int(floor(effective_density * 3.0))
			var remainder: float = fmod(effective_density * 3.0, 1.0)

			# Sumar pesos de especies
			var total_weight: float = 0.0
			for sp in species_list:
				if sp != null and "density_weight" in sp:
					total_weight += maxf(sp.density_weight, 0.01)

			if total_weight <= 0.0001:
				continue

			# Determinar cantidad determinista de briznas para la celda
			var cell_hash := int(("%d:%d:%d" % [fol_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var blade_count := base_count
			if rng.randf() < remainder:
				blade_count += 1

			for k in range(blade_count):
				# Sub-semilla aislada para cada brizna
				var blade_rng := RandomNumberGenerator.new()
				blade_rng.seed = int(("%d:%d" % [cell_hash, k]).hash()) & 0x7FFFFFFF

				# Selección de especie por ruleta de peso
				var roll := blade_rng.randf() * total_weight
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

				# Jitter sub-celda
				var jx := (blade_rng.randf() - 0.5) * 0.85
				var jz := (blade_rng.randf() - 0.5) * 0.85
				var world_x := float(x) + 0.5 + jx
				var world_z := float(y) + 0.5 + jz
				var world_y := cell.height

				var rot_y := blade_rng.randf_range(0.0, TAU)
				var sc_mult := blade_rng.randf_range(0.85, 1.25)
				var scale := Vector3(
					chosen_species.scale_min.x * sc_mult,
					blade_rng.randf_range(chosen_species.scale_min.y, chosen_species.scale_max.y) * sc_mult,
					chosen_species.scale_min.z * sc_mult
				)

				var tr := Transform3D()
				tr.basis = Basis(Vector3.UP, rot_y).scaled(scale)
				tr.origin = Vector3(world_x, world_y, world_z)

				# Variación de tinte sutil por brizna
				var tint_val := blade_rng.randf_range(0.92, 1.08)
				var color := Color(tint_val, tint_val, tint_val, 1.0)

				foliage_data.add_instance(chosen_species.id, tr, color)

	return foliage_data
