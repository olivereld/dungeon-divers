extends SceneTree

const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _ComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const _GridScript = preload("res://src/gameplay/movement/movement_grid.gd")

func _init() -> void:
	print("--- TESTING JUMP FOR DELTA=1 and DELTA=2 ---")
	var grid = _GridScript.new(1.0, Vector3.ZERO)
	# (0, 0): level 0
	# (1, 0): level 1 (delta = 1)
	# (2, 0): level 2 (delta = 2)
	grid.set_cell(Vector2i(0, 0), true, 0.0, 0)
	grid.set_cell(Vector2i(1, 0), true, 2.0, 1)
	grid.set_cell(Vector2i(2, 0), true, 4.0, 2)

	var profile = _ProfileScript.new()
	profile.can_drop = true
	profile.max_drop_distance = 4
	profile.max_step_up = 1
	profile.max_step_down = 1
	profile.require_jump_for_elevation = true

	var rules = _RulesScript.new()

	print("Testing WALK from (0,0) to (1,0) [delta=+1, is_jump=false]:")
	var r1 = rules.validate_transition(Vector2i(0,0), Vector2i(1,0), grid, profile, null, null, false)
	print("  accepted=", r1.accepted, " reason=", r1.reason)

	print("Testing JUMP from (0,0) to (1,0) [delta=+1, is_jump=true]:")
	var r2 = rules.validate_transition(Vector2i(0,0), Vector2i(1,0), grid, profile, null, null, true)
	print("  accepted=", r2.accepted, " transition_type=", r2.transition_type)

	print("Testing WALK from (1,0) to (0,0) [delta=-1, is_jump=false]:")
	var r3 = rules.validate_transition(Vector2i(1,0), Vector2i(0,0), grid, profile, null, null, false)
	print("  accepted=", r3.accepted, " reason=", r3.reason)

	print("Testing JUMP from (1,0) to (0,0) [delta=-1, is_jump=true]:")
	var r4 = rules.validate_transition(Vector2i(1,0), Vector2i(0,0), grid, profile, null, null, true)
	print("  accepted=", r4.accepted, " transition_type=", r4.transition_type)

	# Now delta = 2:
	print("Testing JUMP from (0,0) to (2,0) [delta=+2, is_jump=true]:")
	var r5 = rules.validate_transition(Vector2i(0,0), Vector2i(2,0), grid, profile, null, null, true)
	print("  accepted=", r5.accepted, " reason=", r5.reason)

	print("Testing JUMP from (2,0) to (0,0) [delta=-2, is_jump=true]:")
	var r6 = rules.validate_transition(Vector2i(2,0), Vector2i(0,0), grid, profile, null, null, true)
	print("  accepted=", r6.accepted, " transition_type=", r6.transition_type)

	quit(0)
