extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	# Print reaches of all rivers touching (30-36, 18-26)
	for r_id in range(hydro.rivers.size()):
		var r = hydro.rivers[r_id]
		var touches := false
		for p in r.path:
			if p.x >= 30 and p.x <= 36 and p.y >= 18 and p.y <= 26:
				touches = true
				break
		if touches:
			print("River %d touches area! path size=%d" % [r_id, r.path.size()])
			for i in range(r.path.size()):
				var p = r.path[i]
				if p.x >= 30 and p.x <= 36 and p.y >= 18 and p.y <= 26:
					var p3d = r.points[i]
					print("  r%d pt[%d]=%s lvl=%d y=%.2f w=%.2f d=%.2f" % [r_id, i, str(p), r.levels[i], p3d.y, r.widths[i], r.depths[i]])

	quit(0)
