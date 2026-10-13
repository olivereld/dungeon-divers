extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _VisualizerScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")

func _init() -> void:
	print("--- TESTING PLAYER AT (8, 18) ---")
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 2)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 2
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 2)
	chunk_world.load_initial_area(Vector2i.ZERO, 2)

	var nav_grid = chunk_world.navigation_grid
	var player = _PlayerTestScript.new()
	player.position = Vector3(8.0, 6.0, 18.0)
	root.add_child(player)
	player.setup_movement(nav_grid, null, Vector2i(8, 18))

	var mc = player.movement_component
	print("MC profile: require_jump=", mc.profile.require_jump_for_elevation, " max_step_up=", mc.profile.max_step_up, " max_step_down=", mc.profile.max_step_down, " can_drop=", mc.profile.can_drop)

	# Test all 8 directions from (8, 18)
	for dir in mc.profile.allowed_directions:
		var target = Vector2i(8, 18) + dir
		var res_walk = mc.rules.validate_transition(Vector2i(8, 18), target, nav_grid, mc.profile, null, player, false)
		var res_jump = mc.rules.validate_transition(Vector2i(8, 18), target, nav_grid, mc.profile, null, player, true)
		var t_lvl = nav_grid.get_elevation_level(target) if nav_grid.has_cell(target) else -99
		var t_h = nav_grid.get_height(target) if nav_grid.has_cell(target) else -99.0
		var t_w = nav_grid.is_walkable(target) if nav_grid.has_cell(target) else false
		print("Dir ", dir, " -> target ", target, " lvl=", t_lvl, " h=", t_h, " w=", t_w, " walk_acc=", res_walk.accepted, "(", res_walk.reason, ") jump_acc=", res_jump.accepted, "(", res_jump.reason, " type=", res_jump.transition_type, ")")

	# Test find_best_jump_direction for different facings
	for dir in mc.profile.allowed_directions:
		mc.facing = dir
		var best = mc.find_best_jump_direction()
		print("Facing ", dir, " -> find_best_jump_direction: ", best)

	quit(0)
