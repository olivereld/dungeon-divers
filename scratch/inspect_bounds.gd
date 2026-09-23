extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	var min_x = 999999
	var max_x = -999999
	var min_y = 999999
	var max_y = -999999

	for p in shared_hydrology.water_cells.keys():
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	print("water_cells count: ", shared_hydrology.water_cells.size())
	print("bounds: x in [%d, %d], y in [%d, %d]" % [min_x, max_x, min_y, max_y])
	print("profile width: %d, height: %d" % [profile.width, profile.height])
	quit(0)
