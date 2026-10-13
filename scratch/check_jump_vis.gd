extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WorldNavVisScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")

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
	var vis = _WorldNavVisScript.new()

	print("=== EVALUATING JUMPABLE EDGES NEAR (19, -61) ===")
	for y in range(-68, -55):
		for x in range(14, 26):
			var c := Vector2i(x, y)
			if not nav_grid.has_cell(c):
				continue
			var info = vis._evaluate_jumpable_edges(c, nav_grid)
			var can_jump_up: bool = info.get("can_jump_up", false)
			var can_jump_down: bool = info.get("can_jump_down", false)
			var w: bool = nav_grid.is_walkable(c)
			var h: float = nav_grid.get_height(c)
			var el: int = nav_grid.get_elevation_level(c)
			if can_jump_up or can_jump_down:
				print("Cell (%d, %d): h=%.0f, el=%d, w=%s -> UP=%s, DOWN=%s" % [x, y, h, el, w, can_jump_up, can_jump_down])

	quit(0)
