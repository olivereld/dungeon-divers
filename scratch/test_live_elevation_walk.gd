extends SceneTree

const _SceneScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")
const _MovementRequestScript = preload("res://src/gameplay/movement/movement_request.gd")

var _frame := 0
var _scene = null

func _init() -> void:
	_scene = _SceneScript.new()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false

	var player = _scene.player
	var comp = player.movement_component
	var grid = comp.grid

	print("Initial player cell: ", comp.current_cell)
	print("Initial player pos: ", player.global_position)

	# Teleport player right next to the step: (7, 16) [el=2] -> (8, 16) [el=3]
	comp.teleport_to_cell(Vector2i(7, 16))
	print("Teleported to: ", comp.current_cell)
	print("Elevation at (7, 16): ", grid.get_elevation_level(Vector2i(7, 16)))
	print("Elevation at (8, 16): ", grid.get_elevation_level(Vector2i(8, 16)))

	# Try walking to (8, 16) (+X)
	var req_walk = _MovementRequestScript.new(Vector2i(1, 0), &"player", false)
	var res_walk = comp.request_movement(req_walk)
	print("Walk step to (8, 16) accepted? ", res_walk.accepted if res_walk != null else "null")
	if res_walk != null and not res_walk.accepted:
		print("  Reason: ", res_walk.reason)
	elif res_walk != null:
		print("  Transition type: ", res_walk.transition_type)

	# Process 60 frames
	for frame in range(60):
		comp.process_movement(1.0 / 60.0)

	print("After walk, player cell: ", comp.current_cell)
	print("After walk, player pos: ", player.global_position)

	# Try walking down back to (7, 16) (-X)
	var req_walk_down = _MovementRequestScript.new(Vector2i(-1, 0), &"player", false)
	var res_walk_down = comp.request_movement(req_walk_down)
	print("Walk step down to (7, 16) accepted? ", res_walk_down.accepted if res_walk_down != null else "null")
	if res_walk_down != null and not res_walk_down.accepted:
		print("  Reason: ", res_walk_down.reason)
	elif res_walk_down != null:
		print("  Transition type: ", res_walk_down.transition_type)

	for frame in range(60):
		comp.process_movement(1.0 / 60.0)

	print("After step down, player cell: ", comp.current_cell)
	print("After step down, player pos: ", player.global_position)

	quit(0)
	return true
