extends SceneTree

const _TransformScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_grid_transform.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_grid_transform ---")
	var t = _TransformScript.new()
	t.cell_size = 16.0
	t.zoom = 1.0
	t.offset = Vector2.ZERO

	# 1. Identity transform
	var world_pos := Vector2(100.0, 50.0)
	var screen_pos = t.world_to_screen(world_pos)
	assert(screen_pos.is_equal_approx(Vector2(100.0, 50.0)), "FAIL: identity screen pos mismatch")
	var back_world = t.screen_to_world(screen_pos)
	assert(back_world.is_equal_approx(world_pos), "FAIL: roundtrip world pos mismatch")

	# 2. Pan
	t.pan(Vector2(20.0, 30.0))
	assert(t.offset.is_equal_approx(Vector2(20.0, 30.0)), "FAIL: pan offset mismatch")
	screen_pos = t.world_to_screen(world_pos)
	assert(screen_pos.is_equal_approx(Vector2(120.0, 80.0)), "FAIL: panned screen pos mismatch")

	# 3. Zoom at center
	t.offset = Vector2.ZERO
	t.zoom_at(Vector2(200.0, 200.0), 2.0)
	assert(is_equal_approx(t.zoom, 2.0), "FAIL: zoom factor mismatch")
	# Point under cursor before zoom (200, 200) should remain under cursor after zoom
	var cursor_world = t.screen_to_world(Vector2(200.0, 200.0))
	assert(cursor_world.is_equal_approx(Vector2(200.0, 200.0)), "FAIL: zoom anchor mismatch")

	# 4. Visible world rect culling
	var view_size := Vector2(800.0, 600.0)
	var vis_rect = t.visible_world_rect(view_size)
	assert(vis_rect.size.is_equal_approx(view_size / 2.0), "FAIL: visible rect size mismatch with 2x zoom")

	print("PASS: test_dungeon_lab_grid_transform passed!")
	quit(0)
