extends SceneTree

const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _VisualizerScript = preload("res://src/world_generator/navigation/world_navigation_visualizer.gd")
const _NavGridScript = preload("res://src/world_generator/navigation/world_navigation_grid.gd")
const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Testing Jumpable Elevation Limits (Up to 3 blocks)")
	print("==================================================")
	_test_movement_rules_jump_up_limits()
	_test_visualizer_detection_limits()
	print("==================================================")
	print(" ALL JUMPABLE ELEVATION TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_movement_rules_jump_up_limits() -> void:
	print(" -> Testing MovementRules with max_step_up = 3 and max_drop = 4...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var profile := _ProfileScript.new()
	profile.max_step_up = 3
	profile.max_drop_distance = 4
	profile.can_drop = true
	profile.require_jump_for_elevation = true

	var cells := {}
	# Center at (5, 5): Level 0
	var c0 := _WorldCellScript.new(Vector2i(5, 5))
	c0.elevation_level = 0
	c0.height = 0.0
	c0.is_walkable = true
	cells[Vector2i(5, 5)] = c0

	# +1 Level: (6, 5)
	var c_up1 := _WorldCellScript.new(Vector2i(6, 5))
	c_up1.elevation_level = 1
	c_up1.height = 2.0
	c_up1.is_walkable = true
	cells[Vector2i(6, 5)] = c_up1

	# +2 Levels: (5, 6)
	var c_up2 := _WorldCellScript.new(Vector2i(5, 6))
	c_up2.elevation_level = 2
	c_up2.height = 4.0
	c_up2.is_walkable = true
	cells[Vector2i(5, 6)] = c_up2

	# +3 Levels: (4, 5)
	var c_up3 := _WorldCellScript.new(Vector2i(4, 5))
	c_up3.elevation_level = 3
	c_up3.height = 6.0
	c_up3.is_walkable = true
	cells[Vector2i(4, 5)] = c_up3

	# +4 Levels: (5, 4) (Too high for jump up!)
	var c_up4 := _WorldCellScript.new(Vector2i(5, 4))
	c_up4.elevation_level = 4
	c_up4.height = 8.0
	c_up4.is_walkable = true
	cells[Vector2i(5, 4)] = c_up4

	var chunk := _NavChunkScript.from_cells(Vector2i.ZERO, Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk)

	var rules := _RulesScript.new()

	profile.require_jump_for_elevation = true

	# 1. Normal walk with +1 level without jump must be rejected
	var walk_1 := rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, profile, null, null, false)
	assert(not walk_1.accepted, "Walk with +1 level without jump must be rejected when require_jump_for_elevation = true")
	assert(walk_1.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	# 2. Normal walk with +2 levels without jump must be rejected
	var walk_2 := rules.validate_transition(Vector2i(5, 5), Vector2i(5, 6), grid, profile, null, null, false)
	assert(not walk_2.accepted, "Walk with +2 levels without jump must be rejected")
	assert(walk_2.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	# 3. Jump up +1, +2, +3 must all be accepted as JUMP_UP
	var jump_1 := rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, profile, null, null, true)
	assert(jump_1.accepted, "+1 level jump must be accepted")
	assert(jump_1.transition_type == _RulesScript._ResultScript.TransitionType.JUMP_UP, "+1 must be JUMP_UP")

	var jump_2 := rules.validate_transition(Vector2i(5, 5), Vector2i(5, 6), grid, profile, null, null, true)
	assert(jump_2.accepted, "+2 levels jump must be accepted")
	assert(jump_2.transition_type == _RulesScript._ResultScript.TransitionType.JUMP_UP, "+2 must be JUMP_UP")

	var jump_3 := rules.validate_transition(Vector2i(5, 5), Vector2i(4, 5), grid, profile, null, null, true)
	assert(jump_3.accepted, "+3 levels jump must be accepted")
	assert(jump_3.transition_type == _RulesScript._ResultScript.TransitionType.JUMP_UP, "+3 must be JUMP_UP")

	# 4. Jump up +4 must be rejected (exceeds max_step_up = 3)
	var jump_4 := rules.validate_transition(Vector2i(5, 5), Vector2i(5, 4), grid, profile, null, null, true)
	assert(not jump_4.accepted, "+4 levels jump must be rejected (max height is 3)")
	assert(jump_4.reason == _RulesScript._ResultScript.REASON_ELEVATION_TOO_HIGH, "Reason must be REASON_ELEVATION_TOO_HIGH")

	# 5. Normal walk down -1 level without jump must be rejected
	var walk_down_1 := rules.validate_transition(Vector2i(6, 5), Vector2i(5, 5), grid, profile, null, null, false)
	assert(not walk_down_1.accepted, "Walk down -1 level without jump must be rejected when require_jump_for_elevation = true")
	assert(walk_down_1.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	# 6. Normal walk down -3 levels without jump must be rejected
	var walk_down_3 := rules.validate_transition(Vector2i(4, 5), Vector2i(5, 5), grid, profile, null, null, false)
	assert(not walk_down_3.accepted, "Walk down -3 levels without jump must be rejected")
	assert(walk_down_3.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	# 7. Jump down from +1 to 0 (delta = -1) must be accepted as DROP
	var drop_1 := rules.validate_transition(Vector2i(6, 5), Vector2i(5, 5), grid, profile, null, null, true)
	assert(drop_1.accepted, "Drop of -1 level with jump must be accepted")
	assert(drop_1.transition_type == _RulesScript._ResultScript.TransitionType.DROP, "Transition must be DROP")

	# 8. Jump down from +3 to 0 (delta = -3 <= max_drop=4) must be accepted as DROP
	var drop_3 := rules.validate_transition(Vector2i(4, 5), Vector2i(5, 5), grid, profile, null, null, true)
	assert(drop_3.accepted, "Drop of -3 levels must be accepted")
	assert(drop_3.transition_type == _RulesScript._ResultScript.TransitionType.DROP, "Transition must be DROP")

	# 9. Jump down from +4 to 0 (delta = -4 <= max_drop=4) must be accepted as DROP
	var drop_4 := rules.validate_transition(Vector2i(5, 4), Vector2i(5, 5), grid, profile, null, null, true)
	assert(drop_4.accepted, "Drop of -4 levels must be accepted")
	assert(drop_4.transition_type == _RulesScript._ResultScript.TransitionType.DROP, "Transition must be DROP")

	# 10. Con require_jump_for_elevation = false pero max_walk_step_up = 0 y max_walk_step_down = 0:
	# Caminar a +1 o -1 sin saltar DEBE ser rechazado con REASON_JUMP_REQUIRED (no degradar a STEP_UP ni caer)
	profile.require_jump_for_elevation = false
	profile.max_walk_step_up = 0
	profile.max_walk_step_down = 0
	var walk_no_req_up := rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, profile, null, null, false)
	assert(not walk_no_req_up.accepted, "Walking +1 with walk_up=0 must be rejected even if require_jump_for_elevation=false")
	assert(walk_no_req_up.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	var walk_no_req_down := rules.validate_transition(Vector2i(6, 5), Vector2i(5, 5), grid, profile, null, null, false)
	assert(not walk_no_req_down.accepted, "Walking down -1 with walk_down=0 must be rejected even if require_jump_for_elevation=false")
	assert(walk_no_req_down.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	print("    [PASS] MovementRules enforces jump for all elevation changes (both require_jump_for_elevation true and false with walk=0)")

func _test_visualizer_detection_limits() -> void:
	print(" -> Testing WorldNavigationVisualizer jumpable edge detection...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var profile := _ProfileScript.new()
	profile.max_step_up = 3
	profile.max_drop_distance = 4
	profile.can_drop = true

	var cells := {}
	# Center (5, 5) at Level 0
	var c0 := _WorldCellScript.new(Vector2i(5, 5))
	c0.elevation_level = 0
	c0.is_walkable = true
	cells[Vector2i(5, 5)] = c0

	# Neighbor at (6, 5) at Level 3 (+3 levels difference)
	var c_up3 := _WorldCellScript.new(Vector2i(6, 5))
	c_up3.elevation_level = 3
	c_up3.is_walkable = true
	cells[Vector2i(6, 5)] = c_up3

	var chunk := _NavChunkScript.from_cells(Vector2i.ZERO, Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk)

	var vis := _VisualizerScript.new()
	vis.grid = grid

	# Evaluate from (5, 5) looking at (6, 5): delta = +3 <= 3
	var info_from_bottom := vis._evaluate_jumpable_edges(Vector2i(5, 5), profile)
	assert(info_from_bottom.can_jump_up == true, "(5,5) facing (6,5) must detect can_jump_up = true for 3 blocks")

	# Evaluate from (6, 5) looking down at (5, 5): delta = -3 <= 4
	var info_from_top := vis._evaluate_jumpable_edges(Vector2i(6, 5), profile)
	assert(info_from_top.can_jump_down == true, "(6,5) facing (5,5) must detect can_jump_down = true for -3 blocks")

	# Isolated cell at (10, 10) at Level 5 with only (10, 11) at Level 0 (delta = -5 > 4)
	var c_iso5 := _WorldCellScript.new(Vector2i(10, 10))
	c_iso5.elevation_level = 5
	c_iso5.is_walkable = true
	cells[Vector2i(10, 10)] = c_iso5

	var c_iso0 := _WorldCellScript.new(Vector2i(10, 11))
	c_iso0.elevation_level = 0
	c_iso0.is_walkable = true
	cells[Vector2i(10, 11)] = c_iso0

	var chunk2 := _NavChunkScript.from_cells(Vector2i.ZERO, Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk2)

	var info_from_5 := vis._evaluate_jumpable_edges(Vector2i(10, 10), profile)
	assert(info_from_5.can_jump_down == false, "5-block cliff exceeds max_drop (4), can_jump_down must be false")

	print("    [PASS] WorldNavigationVisualizer accurately flags jump up and drop edges")
