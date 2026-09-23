extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	# Print all rivers where any reach or point has bed_h <= 2.0:
	for r_id in range(hydro.rivers.size()):
		var r = hydro.rivers[r_id]
		for i in range(r.points.size()):
			if r.levels[i] <= 1:
				print("River %d has lvl <= 1 at pt[%d]=%s lvl=%d y=%.2f" % [r_id, i, str(r.path[i]), r.levels[i], r.points[i].y])
				break

	quit(0)
