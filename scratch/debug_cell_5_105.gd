extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _init() -> void:
	var seed_val: int = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 4)

	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	var c06 = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(0, 6), profile, config, shared_hydrology)

	print("Vecindad 5x5 alrededor de (5, 105):")
	for y in range(103, 108):
		var s = "Y=%3d | " % y
		for x in range(3, 8):
			var p = Vector2i(x, y)
			var c = c06.get_cell(p)
			var is_w = shared_hydrology.water_cells.has(p)
			s += "%3.1f%s(raw:%.2f, elev:%d) " % [c.height, "W" if is_w else " ", c.raw_height, c.elevation_level]
		print(s)

	quit(0)
