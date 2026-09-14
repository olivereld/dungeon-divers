extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _RiverEndpoint = preload("res://src/world_generator/hydrology/river_endpoint.gd")

func _init() -> void:
	print("--- Running test_river_depression_interception ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true

	# Test across Seed 2 which contains a large depression (>1.2m deep)
	var result = _WorldPipeline.generate(2, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	var lakes: Array = hydro.lakes
	print("  Seed 2 generated %d lakes" % lakes.size())
	assert(not lakes.is_empty(), "Seed 2 with large depression must generate at least 1 lake")

	var found_lake_dest: bool = false
	for r in hydro.rivers:
		if r.destination_type == _RiverEndpoint.DestinationType.LAKE:
			found_lake_dest = true
			break
	assert(found_lake_dest, "At least one river must have destination_type == LAKE")

	print("test_river_depression_interception: PASSED")
	quit(0)
