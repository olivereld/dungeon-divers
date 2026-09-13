extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	var profile = _TaigaWorldProfileScript.new()
	var result = _WorldPipelineScript.generate(12345, profile)
	var hydro = result.hydrology
	var r = hydro.rivers[2]

	for i in range(10, 14):
		var p: Vector3 = r.points[i]
		var w: float = r.widths[i]
		var d: float = r.depths[i]
		var fb: float = maxf(d * 0.75, 0.25)
		var wh: float = p.y - fb
		var pth: Vector2i = r.path[i]
		var c = result.get_cell(pth)
		print("pt[%d] at (%s): y=%.3f, fb=%.3f, water_y=%.3f, path_pos=(%d,%d), cell.h=%.3f, raw_h=%.3f" % [
			i, str(p), p.y, fb, wh, pth.x, pth.y, c.height, c.raw_height
		])
	quit(0)
