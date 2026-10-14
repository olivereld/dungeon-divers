extends SceneTree

const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _MaterialScript = preload("res://src/world_generator/foliage/rendering/foliage_material.gd")

func _init() -> void:
	print("Running test_foliage_species_types...")
	
	# Test FoliageType enum
	assert(_SpeciesScript.FoliageType.GRASS == 0, "GRASS must be 0")
	assert(_SpeciesScript.FoliageType.FLOWER == 1, "FLOWER must be 1")
	assert(_SpeciesScript.FoliageType.MUSHROOM == 2, "MUSHROOM must be 2")

	# Test new species fields
	var sp_mush := _SpeciesScript.new(&"mush_amanita", "Amanita", "res://assets/texture/foliage/mushrooms/mushroom_single_1.jpg")
	sp_mush.foliage_type = _SpeciesScript.FoliageType.MUSHROOM
	sp_mush.tint_with_grass_color = false
	sp_mush.gradient_influence = 0.85
	sp_mush.canopy_preference = 1.0
	assert(sp_mush.foliage_type == _SpeciesScript.FoliageType.MUSHROOM, "Must assign MUSHROOM type")
	assert(sp_mush.tint_with_grass_color == false, "Mushroom must not tint with grass color")
	assert(sp_mush.gradient_influence == 0.85, "Must store gradient_influence")
	assert(sp_mush.canopy_preference == 1.0, "Must store canopy_preference")

	# Test Material configuration with gradient influence
	var mat = _MaterialScript.get_or_create_material(sp_mush)
	assert(mat != null, "Material must not be null")
	var g_inf = mat.get_shader_parameter("gradient_influence")
	assert(is_equal_approx(float(g_inf), 0.85), "Shader parameter gradient_influence must match species value (got %s)" % str(g_inf))

	print("[PASS] test_foliage_species_types")
	quit(0)
