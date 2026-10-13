extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 6)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 6
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 6)
	chunk_world.load_initial_area(Vector2i(1, -4), 6)

	var nav_grid = chunk_world.navigation_grid

	print("=== ELEVATIONS FROM (19, -61) TO (11, -66) ===")
	for y in range(-68, -58):
		var line := "Y=%3d: " % y
		for x in range(10, 21):
			var c := Vector2i(x, y)
			if nav_grid.has_cell(c):
				line += "[%d:el%d,h%.0f] " % [x, nav_grid.get_elevation_level(c), nav_grid.get_height(c)]
			else:
				line += "   ---    "
		print(line)

	quit(0)
