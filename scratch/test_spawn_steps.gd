extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _MovementRulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _WorldNavVisScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")

func _init() -> void:
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 4)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 4
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 4)
	chunk_world.load_initial_area(Vector2i.ZERO, 4)

	var nav_grid = chunk_world.navigation_grid
	var vis = _WorldNavVisScript.new()
	vis.grid = nav_grid

	var m_profile = _MovementProfileScript.new()
	m_profile.max_step_up = 3
	m_profile.max_drop_distance = 4
	m_profile.require_jump_for_elevation = false
	var rules = _MovementRulesScript.new()

	print("=== ELEVATION CHANGES NEAR (8, 8) ===")
	for y in range(-5, 20):
		for x in range(-5, 20):
			var c := Vector2i(x, y)
			if not nav_grid.has_cell(c):
				continue
			var el: int = nav_grid.get_elevation_level(c)
			var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
			for d: Vector2i in dirs:
				var nc: Vector2i = c + d
				if nav_grid.has_cell(nc):
					var nel: int = nav_grid.get_elevation_level(nc)
					if nel != el and nav_grid.is_walkable(c) and nav_grid.is_walkable(nc):
						var info_c: Dictionary = vis._evaluate_jumpable_edges(c, m_profile)
						var info_nc: Dictionary = vis._evaluate_jumpable_edges(nc, m_profile)
						var res1 = rules.validate_transition(c, nc, nav_grid, m_profile, null, null, false)
						var res2 = rules.validate_transition(nc, c, nav_grid, m_profile, null, null, false)
						print("Step between (%d, %d) [el=%d] and (%d, %d) [el=%d]:" % [c.x, c.y, el, nc.x, nc.y, nel])
						print("  c->nc walk accepted: %s, res: %s" % [res1.accepted, res1.reason])
						print("  nc->c walk accepted: %s, res: %s" % [res2.accepted, res2.reason])
						print("  c vis: up=%s, down=%s" % [info_c.get("can_jump_up", false), info_c.get("can_jump_down", false)])
						print("  nc vis: up=%s, down=%s" % [info_nc.get("can_jump_up", false), info_nc.get("can_jump_down", false)])

	quit(0)
