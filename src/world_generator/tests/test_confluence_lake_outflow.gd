extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_confluence_lake_outflow ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true

	var result = _WorldPipeline.generate(2, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	assert(not hydro.lakes.is_empty(), "Must have lakes")
	for lake in hydro.lakes:
		assert(lake.has("water_height"), "Lake must have water_height")
		assert(lake.has("spillway_pos"), "Lake must have spillway_pos")
		assert(lake.get("cells", []).size() >= 3, "Lake must have at least 3 cells")
		print("  Lake %d: %d cells, water_h=%.2f, spillway_pos=%s" % [
			lake.id, lake.cells.size(), lake.water_height, str(lake.spillway_pos)
		])

	print("test_confluence_lake_outflow: PASSED")
	quit(0)
