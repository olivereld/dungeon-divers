extends SceneTree

func _init() -> void:
	var TaigaWorldProfile = load("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
	var WorldPipeline = load("res://src/world_generator/facade/world_pipeline.gd")
	var profile = TaigaWorldProfile.new()
	var hydro = WorldPipeline.generate_regional_hydrology(12345, profile)
	
	print("Checking cells around (-222, -422)...")
	for dz in range(-4, 5):
		var row := ""
		for dx in range(-4, 5):
			var pos := Vector2i(-222 + dx, -422 + dz)
			if hydro.water_cells.has(pos):
				var wh: float = float(hydro.water_cells[pos].get("water_height", -1.0))
				row += "[%4.1f] " % wh
			else:
				row += "   .   "
		print("z=%4d: %s" % [-422 + dz, row])
	quit(0)
