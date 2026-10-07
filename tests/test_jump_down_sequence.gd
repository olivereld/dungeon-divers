extends SceneTree

const MovementComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const MovementGridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const PlayerScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Jump Down Sequence Test")
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

	assert(player.movement_component != null, "MovementComponent should be present")
	var comp: MovementComponent = player.movement_component
	comp.profile.can_drop = true
	comp.profile.drop_windup_time = 0.35
	comp.profile.drop_flight_time = 0.48

	var flags := {
		"takeoff": false,
		"finished": false
	}
	comp.drop_takeoff.connect(func(_from, _to): flags["takeoff"] = true)
	comp.drop_finished.connect(func(_from, _to): flags["finished"] = true)

	# 1. Solicitar salto hacia abajo (0, 1)
	var res := comp.request_jump(Vector2i(0, 1))
	assert(res != null and res.accepted, "Jump request should be accepted")
	assert(comp.is_in_drop_windup(), "Character should be in drop windup")
	print(" -> [PASS] Jump request accepted and windup initiated")

	# 2. Durante los primeros 0.20s de windup, el personaje NO debe avanzar espacialmente
	comp.process_movement(0.20)
	assert(comp.is_in_drop_windup(), "Still in windup at 0.20s")
	assert(not flags["takeoff"], "takeoff should NOT have fired yet")
	assert(comp.target_actor.position.distance_to(grid.cell_to_world(Vector2i(0, 0))) < 0.05, "Actor must stay at origin ledge during windup")
	print(" -> [PASS] Character remains static on edge during windup phase")

	# 3. Al completar los 0.35s de windup (avanzar 0.16s más)
	comp.process_movement(0.16)
	assert(not comp.is_in_drop_windup(), "Windup should finish at 0.36s")
	assert(flags["takeoff"], "drop_takeoff should have been emitted")
	print(" -> [PASS] drop_takeoff emitted cleanly at windup completion")

	# 4. Proceso de vuelo
	comp.process_movement(0.25)
	assert(comp.is_moving, "Character is flying through the air")
	assert(not flags["finished"], "Drop has not finished yet")

	# Completar vuelo
	comp.process_movement(0.35)
	assert(not comp.is_moving, "Drop finished")
	assert(flags["finished"], "drop_finished emitted")
	assert(comp.current_cell == Vector2i(0, 1), "Character arrived at lower cell")
	print(" -> [PASS] Parabolic flight arrived at destination cell")

	print("==================================================")
	print(" ALL JUMP DOWN SEQUENCE TESTS PASSED!")
	print("==================================================")

	player.free()
	quit(0)
