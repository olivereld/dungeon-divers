extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")

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
	var player = _PlayerTestScript.new()
	root.add_child(player)
	player.setup_movement(nav_grid, null, Vector2i(8, 18))
	var mc = player.movement_component

	print("=== TESTING AT (8, 18) ===")
	print("Player initial cell: ", mc.current_cell)
	mc.profile.require_jump_for_elevation = false
	print("Profile require_jump: ", mc.profile.require_jump_for_elevation)
	print("Profile max_step_up: ", mc.profile.max_step_up)

	# 1. Test WALK towards (9, 18) [East: +X]
	var req_walk = preload("res://src/gameplay/movement/movement_request.gd").new(Vector2i(1, 0), &"player", false)
	var res_walk = mc.request_movement(req_walk)
	print("WALK East -> (9, 18): accepted=", res_walk.accepted, " reason=", res_walk.reason)

	# 2. Test JUMP towards (9, 18) [East: +X]
	var res_jump = mc.request_jump(Vector2i(1, 0))
	print("JUMP East -> (9, 18): accepted=", res_jump != null and res_jump.accepted)
	if res_jump != null:
		print("  jump type=", res_jump.transition_type, " reason=", res_jump.reason)

	# 3. Test WALK towards (8, 17) [North: -Z]
	var req_walk_n = preload("res://src/gameplay/movement/movement_request.gd").new(Vector2i(0, -1), &"player", false)
	var res_walk_n = mc.request_movement(req_walk_n)
	print("WALK North -> (8, 17): accepted=", res_walk_n.accepted, " reason=", res_walk_n.reason)

	# 4. Test JUMP with facing East and no direction arg:
	mc.facing = Vector2i(1, 0)
	var best = mc.find_best_jump_direction()
	print("find_best_jump_direction when facing East: ", best)

	quit(0)
