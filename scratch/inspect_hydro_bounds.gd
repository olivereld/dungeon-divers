extends SceneTree

func _init() -> void:
	var TaigaWorldProfile = load("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
	var WorldPipeline = load("res://src/world_generator/facade/world_pipeline.gd")
	var profile = TaigaWorldProfile.new()
	var hydro = WorldPipeline.generate_regional_hydrology(12345, profile)
	
	print("Hydrology water cells count: ", hydro.water_cells.size())
	var min_p := Vector2i(999999, 999999)
	var max_p := Vector2i(-999999, -999999)
	for p in hydro.water_cells.keys():
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)
	print("Bounding box of water cells: min=", min_p, " max=", max_p)
	quit(0)
