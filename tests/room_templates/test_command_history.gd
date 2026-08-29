extends SceneTree

const _LabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _CmdHistoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/command_history.gd")
const _PaintCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/paint_cells_command.gd")
const _AnchorCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/place_anchor_command.gd")
const _EntranceCmdScript = preload("res://src/dungeon_generator/tools/room_template_lab/commands/place_entrance_command.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_command_history ---")
	var state := _LabStateScript.new()
	var history := _CmdHistoryScript.new(50)

	assert(not history.can_undo(), "FAIL: fresh history cannot undo")
	assert(not history.can_redo(), "FAIL: fresh history cannot redo")

	# 1. Paint Command test
	var paint_cmd = _PaintCmdScript.new(state, { Vector2i(1, 1): 1, Vector2i(1, 2): 1 })
	history.execute(paint_cmd)
	assert(state.get_cell(Vector2i(1, 1)) == 1, "FAIL: cell (1,1) should be 1")
	assert(state.get_cell(Vector2i(1, 2)) == 1, "FAIL: cell (1,2) should be 1")
	assert(history.can_undo(), "FAIL: should be able to undo")

	# Undo
	history.undo()
	assert(state.get_cell(Vector2i(1, 1)) == 0, "FAIL: cell (1,1) should be reverted to 0")
	assert(state.get_cell(Vector2i(1, 2)) == 0, "FAIL: cell (1,2) should be reverted to 0")
	assert(history.can_redo(), "FAIL: should be able to redo")

	# Redo
	history.redo()
	assert(state.get_cell(Vector2i(1, 1)) == 1, "FAIL: cell (1,1) should be redone to 1")

	# 2. Test Anchor Command Undo/Redo
	var anchor_cmd = _AnchorCmdScript.new(state, &"altar", Vector2i(5, 5))
	history.execute(anchor_cmd)
	assert(state.get_anchor(&"altar") == Vector2i(5, 5), "FAIL: altar should be at (5,5)")

	history.undo()
	assert(not state.has_anchor(&"altar"), "FAIL: altar should be undone")

	history.redo()
	assert(state.get_anchor(&"altar") == Vector2i(5, 5), "FAIL: altar should be redone")

	# 3. Test Entrance Command Undo/Redo
	var entrance_cmd = _EntranceCmdScript.new(state, Vector2i(2, 0), true)
	history.execute(entrance_cmd)
	assert(state.get_entrances().has(Vector2i(2, 0)), "FAIL: entrance (2,0) should exist")

	history.undo()
	assert(not state.get_entrances().has(Vector2i(2, 0)), "FAIL: entrance should be undone")

	# 4. Truncate redo stack on new action
	history.undo() # Undo anchor
	assert(history.can_redo(), "FAIL: should be able to redo anchor")
	var paint_cmd2 = _PaintCmdScript.new(state, { Vector2i(3, 3): 1 })
	history.execute(paint_cmd2)
	assert(not history.can_redo(), "FAIL: new action must clear redo stack")

	print("PASS: test_command_history passed successfully!")
	quit(0)
