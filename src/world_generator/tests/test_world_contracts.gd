extends SceneTree

func _init() -> void:
	var profile := WorldProfile.new()
	profile.width = 128
	profile.height = 128
	var result := WorldPipeline.generate(12345, profile)
	assert(result != null, "WorldResult must not be null")
	assert(result.dimensions == Vector2i(128, 128), "Dimensions must match profile")
	assert(result.master_seed == 12345, "Master seed must match")
	assert(result.cells.size() == 128 * 128, "Cell count must match width * height")
	print("test_world_contracts: OK")
	quit()
