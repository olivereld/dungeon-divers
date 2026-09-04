extends SceneTree

const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")
const _TopBarScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_top_bar.tscn")
const _ViewportToolbarScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_viewport_toolbar.tscn")
const _LeftPanelScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_left_panel.tscn")
const _RightPanelScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_right_panel.tscn")
const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lab_ui_components (Cyber-Blueprint UI Suite) ---")
	print("==================================================================")

	_test_1_lab_colors()
	_test_2_top_bar()
	_test_3_viewport_toolbar()
	_test_4_left_panel()
	_test_5_right_panel()
	_test_6_full_lab_integration()

	print("\n>>> ALL LAB UI COMPONENT TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)

func _test_1_lab_colors() -> void:
	print("\n[TEST 1] Verifying LabColors palette and helpers...")
	assert(_LabColors.BG_DARK != Color.BLACK, "FAIL: BG_DARK should not be default")
	assert(_LabColors.ACCENT_AMBER == Color("#f59e0b"), "FAIL: ACCENT_AMBER mismatch")
	assert(_LabColors.ACCENT_CYAN == Color("#22d3ee"), "FAIL: ACCENT_CYAN mismatch")

	var entrance_c = _LabColors.get_room_color("entrance")
	assert(entrance_c == Color("#f59e0b"), "FAIL: entrance color mismatch")
	var boss_c = _LabColors.get_room_color("boss")
	assert(boss_c == Color("#f87171"), "FAIL: boss color mismatch")
	var crypt_c = _LabColors.get_room_color("crypt")
	assert(crypt_c == Color("#a78bfa"), "FAIL: crypt color mismatch")

	var sb = _LabColors.make_flat_panel(_LabColors.BG_PANEL, _LabColors.BORDER_COLOR, 1, 4)
	assert(sb != null, "FAIL: make_flat_panel returned null")
	var badge = _LabColors.make_badge_style(Color.GREEN, Color.DARK_GREEN, 1, 3)
	assert(badge != null, "FAIL: make_badge_style returned null")
	print("  [OK] LabColors validated.")

func _test_2_top_bar() -> void:
	print("\n[TEST 2] Verifying LabTopBar component...")
	var top_bar = _TopBarScene.instantiate()
	root.add_child(top_bar)
	top_bar._ready()

	var view_mode_received: Array = []
	top_bar.view_mode_changed.connect(func(m): view_mode_received.append(m))

	top_bar.set_view_mode(1)
	assert(view_mode_received.size() == 1 and view_mode_received[0] == 1, "FAIL: view_mode_changed signal not fired")
	assert(top_bar.current_view_mode == 1, "FAIL: current_view_mode not updated")

	top_bar.set_status_text("Test Status", false)
	assert(top_bar.status_label.text == "Test Status", "FAIL: status text not updated")

	root.remove_child(top_bar)
	top_bar.queue_free()
	print("  [OK] LabTopBar validated.")

func _test_3_viewport_toolbar() -> void:
	print("\n[TEST 3] Verifying LabViewportToolbar component...")
	var toolbar = _ViewportToolbarScene.instantiate()
	root.add_child(toolbar)
	toolbar._ready()

	var zoom_in_events: Array = []
	toolbar.zoom_in_requested.connect(func(): zoom_in_events.append(true))
	toolbar.btn_zoom_in.pressed.emit()
	assert(zoom_in_events.size() > 0, "FAIL: zoom_in_requested signal not fired")

	toolbar.set_3d_mode(true)
	assert(toolbar.btn_rot_left.visible == true, "FAIL: 3D rotate left button should be visible in 3D mode")
	assert(toolbar.btn_rot_right.visible == true, "FAIL: 3D rotate right button should be visible in 3D mode")

	toolbar.set_3d_mode(false)
	assert(toolbar.btn_rot_left.visible == false, "FAIL: 3D rotate left button should be hidden in 2D mode")

	root.remove_child(toolbar)
	toolbar.queue_free()
	print("  [OK] LabViewportToolbar validated.")

func _test_4_left_panel() -> void:
	print("\n[TEST 4] Verifying LabLeftPanel component...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	panel.update_footer(2, "BSP", 987654)
	assert(panel.footer_badge.text.find("FLOOR 2") != -1, "FAIL: footer floor not updated")
	assert(panel.footer_badge.text.find("BSP") != -1, "FAIL: footer algo not updated")
	assert(panel.footer_badge.text.find("987654") != -1, "FAIL: footer seed not updated")

	var overlay_events: Array = []
	panel.overlay_toggled.connect(func(_n, _v): overlay_events.append(_n))
	var cb_bounds = panel.find_child("CheckRoomBounds", true, false) as CheckBox
	if cb_bounds != null:
		cb_bounds.toggled.emit(false)
		assert(overlay_events.size() > 0, "FAIL: overlay_toggled signal not fired on checkbox click")

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] LabLeftPanel validated.")

class MockTestRoom extends RefCounted:
	var id: int = 1
	var room_type: String = "crypt"
	var rect: Rect2i = Rect2i(5, 5, 10, 8)
	var custom_data: Dictionary = {"resolved_template_id": "crypt_large_01"}

func _test_5_right_panel() -> void:
	print("\n[TEST 5] Verifying LabRightPanel component...")
	var panel = _RightPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	panel.update_summary(123456, 2, "Hybrid", true)
	assert(panel.seed_val_label.text == "123456", "FAIL: seed val not updated")
	assert(panel.status_badge.text == "VALID", "FAIL: status badge not updated")

	panel.update_metrics(5, 4, 3, 2, 4, 1, 18.5)
	assert(panel.rooms_val.text == "5", "FAIL: rooms val not updated")
	assert(panel.corridors_val.text == "4", "FAIL: corridors val not updated")
	assert(panel.gen_time_val.text.find("18.5") != -1, "FAIL: gen time val not updated")

	var mock_room = MockTestRoom.new()
	panel.populate_rooms([mock_room], -1)
	assert(panel.rooms_list_container.get_child_count() == 1, "FAIL: rooms list item not created")

	var room_selected_events: Array = []
	panel.room_selected.connect(func(r_id):
		if r_id == 1: room_selected_events.append(r_id)
	)
	var item_btn = panel.rooms_list_container.get_child(0) as Button
	item_btn.pressed.emit()
	assert(room_selected_events.size() > 0, "FAIL: room_selected signal not emitted on item click")
	assert(panel.room_detail_card.visible == true, "FAIL: room detail card should be visible")
	assert(panel.detail_title.text == "ROOM #1", "FAIL: room detail title mismatch")

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] LabRightPanel validated.")

func _test_6_full_lab_integration() -> void:
	print("\n[TEST 6] Verifying full DungeonLevelLab scene assembly & live generation...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	assert(lab.ui_top_bar != null, "FAIL: ui_top_bar not bound")
	assert(lab.ui_left_panel != null, "FAIL: ui_left_panel not bound")
	assert(lab.ui_viewport_toolbar != null, "FAIL: ui_viewport_toolbar not bound")
	assert(lab.ui_right_panel != null, "FAIL: ui_right_panel not bound")
	assert(lab.renderer != null, "FAIL: renderer not bound")
	assert(lab.viewer_3d != null, "FAIL: viewer_3d not bound")

	lab.config.seed = 202609
	lab.config.floor_count = 1
	lab.generate_current()

	var sem_res = lab.controller.get_active_semantic_result()
	assert(sem_res != null, "FAIL: generation should produce active semantic result")
	assert(sem_res.rooms.size() > 0, "FAIL: generation should produce rooms")
	assert(lab.renderer.get_rendered_room_count() > 0, "FAIL: renderer should have rendered rooms")

	# Check right panel populated
	assert(int(lab.ui_right_panel.rooms_val.text) == sem_res.rooms.size(), "FAIL: right panel rooms metric mismatch")
	assert(lab.ui_right_panel.rooms_list_container.get_child_count() == sem_res.rooms.size(), "FAIL: rooms list count mismatch")

	# Test 2D/3D mode toggle
	lab.set_view_mode(1) # 3D
	assert(lab.current_view_mode == 1, "FAIL: should be in 3D mode")
	assert(lab.viewport_container_3d.visible == true, "FAIL: 3D viewport should be visible")
	assert(lab.renderer.visible == false, "FAIL: 2D renderer should be hidden")

	lab.set_view_mode(0) # 2D
	assert(lab.current_view_mode == 0, "FAIL: should be in 2D mode")
	assert(lab.renderer.visible == true, "FAIL: 2D renderer should be visible")
	assert(lab.viewport_container_3d.visible == false, "FAIL: 3D viewport should be hidden")

	lab.queue_free()
	print("  [OK] Full DungeonLevelLab integration validated.")
