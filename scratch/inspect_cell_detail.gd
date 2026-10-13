extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _MovementRulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")

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
	var m_profile = _MovementProfileScript.new()
	m_profile.max_step_up = 3
	m_profile.max_drop_distance = 4
	m_profile.require_jump_for_elevation = false
	var rules = _MovementRulesScript.new()

	print("=== DETAILED SURROUNDINGS OF (19, -61) ===")
	for dy in range(-3, 4):
		var line := ""
		for dx in range(-3, 4):
			var c := Vector2i(19 + dx, -61 + dy)
			if nav_grid.has_cell(c):
				var h: float = nav_grid.get_height(c)
				var el: int = nav_grid.get_elevation_level(c)
				var w: bool = nav_grid.is_walkable(c)
				line += "[%d,%d: h=%.0f,el=%d,%s] " % [c.x, c.y, h, el, "W" if w else "X"]
			else:
				line += "[NO CELL] "
		print(line)

	print("\n=== EVALUATING MOVEMENT FROM (19, -61) IN ALL 8 DIRECTIONS ===")
	var from_cell := Vector2i(19, -61)
	var dirs = [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
	]
	var dir_names = ["E (+X)", "SE (+X,+Z)", "S (+Z)", "SW (-X,+Z)", "W (-X)", "NW (-X,-Z)", "N (-Z)", "NE (+X,-Z)"]
	for i in range(dirs.size()):
		var d: Vector2i = dirs[i]
		var target: Vector2i = from_cell + d
		var res_walk = rules.validate_transition(from_cell, target, nav_grid, m_profile, null, null, false)
		var res_jump = rules.validate_transition(from_cell, target, nav_grid, m_profile, null, null, true)
		print("Dir %s to (%d, %d):" % [dir_names[i], target.x, target.y])
		print("  Walk: accepted=%s, type=%s, reason=%s" % [res_walk.accepted, res_walk.transition_type, res_walk.rejection_reason])
		print("  Jump: accepted=%s, type=%s, reason=%s" % [res_jump.accepted, res_jump.transition_type, res_jump.rejection_reason])

	quit(0)
