extends SceneTree

const _CanvasViewScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_canvas_view.gd")
const _LabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _CmdHistoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/command_history.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_canvas_view ---")
	var state := _LabStateScript.new()
	var history := _CmdHistoryScript.new()
	state.command_history = history

	var canvas = _CanvasViewScript.new()
	canvas.setup(state, history)
	canvas.size = Vector2(800.0, 600.0)

	# 1. Verify canvas delegates to GridTransform
	assert(canvas.grid_transform != null, "FAIL: grid_transform should exist")
	var cell: Vector2i = canvas.grid_transform.screen_to_cell(Vector2(400.0, 300.0))
	assert(cell is Vector2i, "FAIL: coordinate transform should return Vector2i")

	# 2. Test cell mutation via canvas tool logic
	canvas.apply_brush_at_cell(Vector2i(5, 5), 1)
	assert(state.get_cell(Vector2i(5, 5)) == 1, "FAIL: brush should paint cell (5,5)")
	assert(history.can_undo(), "FAIL: canvas actions must push to command history")

	# 3. Test mirror painting
	state.mirror_paint_enabled = true
	state.symmetry_axis = &"vertical"
	# Assuming center is at x=5, painting at x=7 should also paint at x=3
	canvas.apply_brush_with_symmetry(Vector2i(7, 5), 1, 5)
	assert(state.get_cell(Vector2i(7, 5)) == 1, "FAIL: primary mirrored cell should be painted")
	assert(state.get_cell(Vector2i(3, 5)) == 1, "FAIL: symmetrical mirrored cell should be painted")

	canvas.free()
	print("PASS: test_room_template_canvas_view passed successfully!")
	quit(0)
