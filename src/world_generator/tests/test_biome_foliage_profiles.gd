extends SceneTree

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Biome Foliage Profiles Test Suite (Tarea 6)")
	print("==================================================")

	var reg = _BiomeRegistryScript.get_default()
	var expected_biomes = [
		_BiomeIdScript.TAIGA,
		_BiomeIdScript.TUNDRA,
		_BiomeIdScript.TEMPERATE_FOREST,
		_BiomeIdScript.DESERT,
		_BiomeIdScript.JUNGLE,
		_BiomeIdScript.ALPINE
	]

	for b_id in expected_biomes:
		assert(reg.has_definition(b_id), "Biome '%s' must be registered" % String(b_id))
		var b_def = reg.get_definition(b_id)
		assert(b_def != null, "Definition must not be null")
		assert(b_def.foliage_profile != null, "Biome '%s' must have a non-null foliage_profile" % String(b_id))
		var fol_prof = b_def.foliage_profile
		assert(fol_prof.base_density >= 0.0, "Base density must be non-negative")
		assert(not fol_prof.species.is_empty(), "Biome '%s' foliage_profile must contain at least 1 species" % String(b_id))

		for sp in fol_prof.species:
			assert(sp != null, "Species in '%s' must not be null" % String(b_id))
			assert(ResourceLoader.exists(sp.texture_path), "Texture for species '%s' in biome '%s' must exist at path: %s" % [
				String(sp.id), String(b_id), sp.texture_path
			])
		print(" -> [PASS] Biome '%s' has valid FoliageProfile with %d species" % [String(b_id), fol_prof.species.size()])

	print("==================================================")
	print(" ALL BIOME FOLIAGE PROFILE TESTS PASSED!")
	print("==================================================")
	quit(0)
