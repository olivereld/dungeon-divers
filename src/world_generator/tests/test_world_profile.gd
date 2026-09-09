extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	assert(profile.width == 128)
	assert(profile.height == 128)
	assert(profile.macro_frequency > 0.0)
	assert(profile.height_scale > 0.0)
	assert(profile.max_walkable_slope > 0.0)
	assert(profile.tree_density >= 0.0 and profile.tree_density <= 1.0)
	print("test_world_profile: OK")
	quit()
