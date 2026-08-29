extends SceneTree

const _GridTransformScript = preload("res://src/dungeon_generator/tools/room_template_lab/grid_transform.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_grid_transform ---")
	var gt := _GridTransformScript.new(32.0, 1.0, Vector2(100.0, 100.0))

	# 1. Test cell to screen
	var s_pos = gt.cell_to_screen(Vector2i(0, 0))
	assert(s_pos.is_equal_approx(Vector2(100.0, 100.0)), "FAIL: cell (0,0) screen pos should be (100,100)")

	var s_pos_2 = gt.cell_to_screen(Vector2i(2, 3))
	assert(s_pos_2.is_equal_approx(Vector2(164.0, 196.0)), "FAIL: cell (2,3) screen pos mismatch")

	# 2. Test screen to cell
	var c_pos = gt.screen_to_cell(Vector2(110.0, 110.0))
	assert(c_pos == Vector2i(0, 0), "FAIL: (110,110) should be cell (0,0)")

	var c_pos_2 = gt.screen_to_cell(Vector2(165.0, 197.0))
	assert(c_pos_2 == Vector2i(2, 3), "FAIL: (165,197) should be cell (2,3)")

	# Negative screen coords
	var c_pos_neg = gt.screen_to_cell(Vector2(80.0, 80.0))
	assert(c_pos_neg == Vector2i(-1, -1), "FAIL: (80,80) should be cell (-1,-1)")

	# 3. Test Zoom transformation
	gt.zoom = 2.0
	var s_pos_zoom = gt.cell_to_screen(Vector2i(1, 1))
	assert(s_pos_zoom.is_equal_approx(Vector2(164.0, 164.0)), "FAIL: zoom 2x cell (1,1) screen pos mismatch")

	var c_pos_zoom = gt.screen_to_cell(Vector2(165.0, 165.0))
	assert(c_pos_zoom == Vector2i(1, 1), "FAIL: zoom 2x screen to cell mismatch")

	# 4. Test visible_cell_range culling bounds
	gt.zoom = 1.0
	gt.pan_offset = Vector2.ZERO
	var viewport := Vector2(320.0, 320.0) # 10x10 cells
	var range_rect = gt.visible_cell_range(viewport)
	assert(range_rect.position.x <= 0 and range_rect.end.x >= 10, "FAIL: visible range X mismatch")
	assert(range_rect.position.y <= 0 and range_rect.end.y >= 10, "FAIL: visible range Y mismatch")

	print("PASS: test_grid_transform passed successfully!")
	quit(0)
