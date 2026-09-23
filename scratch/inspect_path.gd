extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	var r0 = hydro.rivers[0]
	print("Inspecting River 0 path and points:")
	for i in range(r0.points.size()):
		var p = r0.path[i]
		if p.x >= 28 and p.x <= 36 and p.y >= 19 and p.y <= 26:
			print("  path[%d]=%s lvl=%d pt_y=%.2f w=%.2f d=%.2f" % [i, str(p), r0.levels[i], r0.points[i].y, r0.widths[i], r0.depths[i]])

	quit(0)
