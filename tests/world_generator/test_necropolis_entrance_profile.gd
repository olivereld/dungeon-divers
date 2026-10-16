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

	# Dead trees semantic height bounds
	assert(prof.dead_tree_height_min == 4.8, "Dead tree height min must default to 4.8m")
	assert(prof.dead_tree_height_max == 7.0, "Dead tree height max must default to 7.0m")
	assert(prof.dead_tree_density == 0.25, "Dead tree density must default to 0.25")

	# Fallen wood profile parameters
	assert(prof.stump_density == 0.12, "Stump density must default to 0.12")
	assert(prof.stump_height_min == 0.35, "Stump height min must default to 0.35m")
	assert(prof.stump_height_max == 0.80, "Stump height max must default to 0.80m")
	assert(prof.log_density == 0.10, "Log density must default to 0.10")
	assert(prof.log_length_min == 1.5, "Log length min must default to 1.5m")
	assert(prof.log_length_max == 4.0, "Log length max must default to 4.0m")
	assert(prof.fallen_wood_min_distance == 2.0, "Fallen wood min distance must default to 2.0m")

	# Fungal accent parameters
	assert(prof.mushroom_density == 0.08, "Mushroom density must default to 0.08")
	assert(prof.mushroom_scale_min == 0.65, "Mushroom scale min must default to 0.65")
	assert(prof.mushroom_scale_max == 1.15, "Mushroom scale max must default to 1.15")

	print("[PASS] test_necropolis_entrance_profile")
	quit(0)
