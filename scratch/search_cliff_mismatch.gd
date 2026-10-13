extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _VisualizerScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")

func _init() -> void:
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 3)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 3
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 3)
	chunk_world.load_initial_area(Vector2i.ZERO, 3)

	var nav_grid = chunk_world.navigation_grid
	var vis = _VisualizerScript.new()
	vis.grid = nav_grid

	var player = _PlayerTestScript.new()
	root.add_child(player)
	player.setup_movement(nav_grid, null, Vector2i(8, 8))
	var p_profile = player.movement_component.profile

	# Search across all loaded cells: is there ANY pair of adjacent cells A and B
	# where A is walkable, B is walkable, elevation_level(A) != elevation_level(B),
	# but NEITHER is marked jumpable?
	var mismatches := 0
	for y in range(-32, 48):
		for x in range(-32, 48):
			var c1 := Vector2i(x, y)
			if not nav_grid.has_cell(c1) or not nav_grid.is_walkable(c1):
				continue
			var el1: int = nav_grid.get_elevation_level(c1)
			var j1: Dictionary = vis._evaluate_jumpable_edges(c1, p_profile)

			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var c2: Vector2i = c1 + dir
				if not nav_grid.has_cell(c2) or not nav_grid.is_walkable(c2):
					continue
				var el2: int = nav_grid.get_elevation_level(c2)
				var j2: Dictionary = vis._evaluate_jumpable_edges(c2, p_profile)

				if el1 != el2:
					var diff: int = absi(el1 - el2)
					# If diff <= 3, c1 and c2 MUST have jump flags!
					if diff <= 3:
						if not j1.can_jump_up and not j1.can_jump_down:
							print("MISMATCH at ", c1, " el=", el1, " neighbor ", c2, " el=", el2)
							mismatches += 1

	print("Total mismatches where diff <= 3 but not jumpable: ", mismatches)
	quit(0)
