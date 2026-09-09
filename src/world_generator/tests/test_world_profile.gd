extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	assert(profile.width == 128)
	assert(profile.height == 128)
	assert(profile.macro_frequency > 0.0)
	assert(profile is Resource, "WorldProfile must extend Resource")
	assert(profile.relief_exponent > 0.0, "relief_exponent must be set")
	assert(profile.warp_octaves >= 1 and profile.warp_octaves <= 4, "warp_octaves must be within range")
	assert(profile.max_walkable_slope > 0.0)
	assert(profile.tree_density >= 0.0 and profile.tree_density <= 1.0)
	print("test_world_profile: OK")
	quit()
