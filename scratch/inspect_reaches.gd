extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	for r_id in [0, 1]:
		var r = hydro.rivers[r_id]
		print("River %d levels: %s" % [r_id, str(r.levels)])
		print("River %d depths around 38: " % r_id)
		for i in range(r.points.size()):
			if r.levels[i] <= 2:
				print("  pt[%d]=%s lvl=%d y=%.2f w=%.2f d=%.2f" % [i, str(r.path[i]), r.levels[i], r.points[i].y, r.widths[i], r.depths[i]])
				break

	quit(0)
