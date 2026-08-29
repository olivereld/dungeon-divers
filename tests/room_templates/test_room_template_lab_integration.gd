extends SceneTree

const _LabScene = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab.tscn")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_lab_integration ---")
	var lab_instance = _LabScene.instantiate()
	assert(lab_instance != null, "FAIL: lab scene instantiation failed")

	root.add_child(lab_instance)
	lab_instance.size = Vector2(1280.0, 720.0)

	# 1. Verify lab state and components initialization
	assert(lab_instance.state != null, "FAIL: lab state is null")
	assert(lab_instance.canvas_view != null, "FAIL: canvas view is null")
	assert(lab_instance.toolbar != null, "FAIL: toolbar is null")
	assert(lab_instance.inspector != null, "FAIL: inspector is null")
	assert(lab_instance.simulator != null, "FAIL: simulator is null")

	# 2. Verify that the first catalog template was auto-rendered and carved on the canvas
	assert(lab_instance.state.get_painted_cell_count() > 0, "FAIL: catalog template should have auto-rendered cells on canvas")

	# 3. Test painting custom floor cells in lab state
	lab_instance.state.clear_canvas()
	lab_instance.state.set_cell(Vector2i(0, 0), 1)
	lab_instance.state.set_cell(Vector2i(1, 0), 1)
	lab_instance.state.set_cell(Vector2i(0, 1), 1)
	lab_instance.state.set_cell(Vector2i(1, 1), 1)
	assert(lab_instance.state.get_painted_cell_count() == 4, "FAIL: 4 cells should be painted")

	# 4. Test Auto-calculate geometry
	var geom = lab_instance.state.auto_calculate_geometry()
	assert(geom["width"] == 2 and geom["height"] == 2, "FAIL: 2x2 bounds mismatch")
	assert(geom["area"] == 4, "FAIL: area should be 4")

	# 5. Test anchor and entrance placement
	lab_instance.state.set_anchor(&"relic_box", Vector2i(0, 0))
	lab_instance.state.add_entrance(Vector2i(1, 1))
	assert(lab_instance.state.has_anchor(&"relic_box"), "FAIL: anchor should exist")
	assert(lab_instance.state.get_entrances().has(Vector2i(1, 1)), "FAIL: entrance should exist")

	# 6. Test building and validating RoomTemplate
	var built_tpl = lab_instance.state.build_template_from_state()
	assert(built_tpl != null, "FAIL: built template should not be null")
	assert(built_tpl.anchors.has(&"relic_box"), "FAIL: built template should have relic_box anchor")

	# Clean up
	lab_instance.queue_free()
	print("PASS: test_room_template_lab_integration passed successfully!")
	quit(0)
