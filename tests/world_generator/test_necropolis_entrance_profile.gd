extends SceneTree

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_profile...")
	var prof = _ProfileScript.new()
	assert(prof != null, "Profile must instantiate")
	assert(prof.entrance_clear_radius == 4.5, "Clear radius must default to 4.5m")
	assert(prof.funeral_ground_radius == 12.0, "Funeral ground radius must default to 12.0m")
	assert(prof.corruption_radius == 22.0, "Corruption radius must default to 22.0m")
	assert(prof.transition_radius == 40.0, "Transition radius must default to 40.0m")
	assert(prof.normal_vegetation_multiplier <= 0.2, "Normal vegetation must be heavily dampened")
	assert(prof.dead_tree_scale_max > prof.dead_tree_scale_min, "Dead tree scale max must exceed min")
	print("[PASS] test_necropolis_entrance_profile")
	quit(0)
