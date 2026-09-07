extends SceneTree

const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_active_modules_tab (Option A & Modules View) ---")
	print("==================================================================")

	var lab = _LabScene.instantiate()
	assert(lab != null, "FAIL: Could not instantiate dungeon_level_lab.tscn")
	root.add_child(lab)
	lab._ready()

	var left_panel = lab.ui_left_panel
	assert(left_panel != null, "FAIL: ui_left_panel must exist")
	left_panel._ensure_nodes()
	left_panel._ready()

	# 1. Verify ModeTabs in LabLeftPanel
	var mode_tabs = left_panel.mode_tabs
	assert(mode_tabs != null, "FAIL: mode_tabs must exist")
	print("  [OK] ModeTabs found. Tab count: %d" % mode_tabs.tab_count)
	assert(mode_tabs.tab_count == 3, "FAIL: ModeTabs must have exactly 3 tabs (Option A)")
	assert(mode_tabs.get_tab_title(0).find("Gen") != -1, "FAIL: Tab 0 must be Gen")
	assert(mode_tabs.get_tab_title(1).find("Room") != -1, "FAIL: Tab 1 must be Room")
	assert(mode_tabs.get_tab_title(2).find("Módulos") != -1, "FAIL: Tab 2 must be Módulos")
	print("  [OK] Tab titles verified: [0] %s, [1] %s, [2] %s" % [
		mode_tabs.get_tab_title(0),
		mode_tabs.get_tab_title(1),
		mode_tabs.get_tab_title(2)
	])

	# 2. Verify Tab Switching
	print("  Testing Tab 0 (Gen)...")
	left_panel._on_tab_changed(0)
	assert(left_panel.gen_scroll.visible == true, "FAIL: GenScroll must be visible on tab 0")
	assert(left_panel.room_scroll.visible == false, "FAIL: RoomScroll must be hidden on tab 0")
	assert(left_panel.modules_scroll.visible == false, "FAIL: ModulesScroll must be hidden on tab 0")

	print("  Testing Tab 1 (Room)...")
	left_panel._on_tab_changed(1)
	assert(left_panel.gen_scroll.visible == false, "FAIL: GenScroll must be hidden on tab 1")
	assert(left_panel.room_scroll.visible == true, "FAIL: RoomScroll must be visible on tab 1")
	assert(left_panel.modules_scroll.visible == false, "FAIL: ModulesScroll must be hidden on tab 1")

	print("  Testing Tab 2 (Módulos)...")
	left_panel._on_tab_changed(2)
	assert(left_panel.gen_scroll.visible == false, "FAIL: GenScroll must be hidden on tab 2")
	assert(left_panel.room_scroll.visible == false, "FAIL: RoomScroll must be hidden on tab 2")
	assert(left_panel.modules_scroll.visible == true, "FAIL: ModulesScroll must be visible on tab 2")

	# 3. Verify Modules Content inside left panel
	var modules_inner = left_panel.modules_inner
	assert(modules_inner != null, "FAIL: ModulesInner must exist")
	var children_count = modules_inner.get_child_count()
	print("  [OK] Modules list populated with %d elements/cards" % children_count)
	assert(children_count > 10, "FAIL: Modules list must contain categories and module cards")

	# 4. Verify Lab Controller Tab Handling & Inspector Output
	lab._on_mode_tab_changed(2)
	assert(lab.current_mode == lab.LabMode.MODULES, "FAIL: Current mode must be LabMode.MODULES")
	assert(lab.inspector_text != null, "FAIL: inspector_text must exist")
	assert(lab.inspector_text.text.find("ARQUITECTURA & MÓDULOS ACTIVOS") != -1, "FAIL: inspector_text must display active modules report")
	assert(lab.inspector_text.text.find("SolidGeometryBuilder") != -1, "FAIL: SolidGeometryBuilder must be listed in inspector")
	assert(lab.inspector_text.text.find("CorridorPruner") != -1, "FAIL: CorridorPruner must be listed in inspector")
	print("  [OK] Inspector successfully updated with active modules architecture report")

	print("\n>>> ALL CHECKS PASSED: OPTION A AND ACTIVE MODULES VIEW FULLY OPERATIONAL! <<<\n")
	lab.queue_free()
	quit(0)
