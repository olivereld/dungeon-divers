extends SceneTree

const _TaigaProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _AutumnProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")

func _init() -> void:
	print("Running test_taiga_foliage_distribution...")
	var taiga := _TaigaProfileScript.new()
	var autumn := _AutumnProfileScript.new()
	
	# Validate Taiga foliage setup
	var t_fol = taiga.foliage_profile if "foliage_profile" in taiga else null
	assert(t_fol != null, "Taiga must provide a foliage_profile")
	assert(t_fol.species.size() >= 2, "Taiga must have at least 2 distinct foliage species (Micro + Medium)")
	
	# Validate Autumn Forest foliage setup
	var a_fol = autumn.foliage_profile if "foliage_profile" in autumn else null
	assert(a_fol != null, "Autumn Forest must provide a foliage_profile")
	assert(a_fol.species.size() >= 2, "Autumn Forest must have at least 2 distinct foliage species")
	
	var has_micro := false
	var has_medium := false
	for sp in t_fol.species:
		if sp.scale_category == _SpeciesScript.ScaleCategory.MICRO:
			has_micro = true
		elif sp.scale_category == _SpeciesScript.ScaleCategory.MEDIUM:
			has_medium = true
	assert(has_micro and has_medium, "Taiga must contain both MICRO and MEDIUM foliage species")
	
	print("[PASS] test_taiga_foliage_distribution")
	quit(0)
