extends SceneTree

const MovementComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const MovementGridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const PlayerScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Jump Animation Integrity Test")
	print("==================================================")

	var c0 := WorldCellScript.new()
	c0.position = Vector2i(0, 0)
	c0.elevation_level = 2
	c0.is_walkable = true

	var c1 := WorldCellScript.new()
	c1.position = Vector2i(0, 1)
	c1.elevation_level = 0
	c1.is_walkable = true

	var grid: MovementGrid = MovementGridScript.new(1.0, Vector3.ZERO)
	grid.setup_from_cells({
		Vector2i(0, 0): c0,
		Vector2i(0, 1): c1,
	})

	var player: PlayerTest = PlayerScript.new()
	root.add_child(player)
	player.setup_movement(grid, null, Vector2i(0, 0))

	var comp: MovementComponent = player.movement_component
	var playback = player.get("_anim_playback")

	# Test 1: Start jump down
	var res := comp.request_jump(Vector2i(0, 1))
	assert(res != null and res.accepted, "Jump accepted")
	assert(player._is_jump_active(), "Jump is active immediately")

	# Verify animation is Takeoff and _update_animation_state does NOT override to Locomotion
	player._update_animation_state()
	if playback != null:
		var cur = String(playback.get_current_node())
		assert(cur != "Locomotion", "Must NOT be Locomotion during jump start, got: " + cur)
	print(" -> [PASS] Jump start does not trigger Locomotion")

	# Test 2: Advance through windup and flight, testing _update_animation_state each tick
	for i in range(10):
		comp.process_movement(0.08)
		player._update_animation_state()
		if playback != null:
			var cur = String(playback.get_current_node())
			assert(cur != "Locomotion", "Must NOT be Locomotion during flight, got: " + cur)

	print(" -> [PASS] Mid-air flight never played Locomotion")

	# Test 3: Finish jump, enter landing
	comp.process_movement(0.2)
	assert(not comp.is_moving, "Movement ended")
	assert(player.get("_is_landing"), "Is landing")
	if playback != null:
		var cur = String(playback.get_current_node())
		assert(cur != "Locomotion", "Landing must NOT be Locomotion, got: " + cur)

	print(" -> [PASS] Landing reached without triggering Locomotion")

	print("==================================================")
	print(" ALL JUMP ANIMATION INTEGRITY TESTS PASSED!")
	print("==================================================")

	player.free()
	quit(0)
