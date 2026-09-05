extends SceneTree

const _LeftPanelScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_left_panel.tscn")
const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")
const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lab_composition_tuning ---")
	print("==================================================================")

	_test_accordions()
	_test_composition_tuning_controls()
	_test_direction_buttons()
	_test_slider_label_sync()
	_test_config_overrides()
	_test_lab_generation_with_overrides()

	print("\n>>> ALL COMPOSITION TUNING & ACCORDION TESTS PASSED! <<<\n")
	quit(0)

func _test_accordions() -> void:
	print("\n[TEST 1] Testing collapsible accordions...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	# Test GenMargin accordion
	assert(panel.gen_header != null, "FAIL: gen_header missing")
	assert(panel.gen_body != null, "FAIL: gen_body missing")
	assert(panel.gen_body.visible == true, "FAIL: gen_body should be open by default")
	assert(panel.gen_header.text.begins_with("▼"), "FAIL: gen_header arrow should be expanded")

	panel.gen_header.pressed.emit()
	assert(panel.gen_body.visible == false, "FAIL: gen_body should collapse on click")
	assert(panel.gen_header.text.begins_with("▶"), "FAIL: gen_header arrow should be collapsed")

	panel.gen_header.pressed.emit()
	assert(panel.gen_body.visible == true, "FAIL: gen_body should expand on second click")
	assert(panel.gen_header.text.begins_with("▼"), "FAIL: gen_header arrow should be expanded")

	# Test StructMargin accordion
	assert(panel.struct_header != null and panel.struct_body != null)
	panel.struct_header.pressed.emit()
	assert(panel.struct_body.visible == false, "FAIL: struct_body should collapse")
	assert(panel.struct_header.text.begins_with("▶"))
	panel.struct_header.pressed.emit()
	assert(panel.struct_body.visible == true, "FAIL: struct_body should expand")

	# Test SemanticMargin accordion
	assert(panel.semantic_header != null and panel.semantic_body != null)
	panel.semantic_header.pressed.emit()
	assert(panel.semantic_body.visible == false, "FAIL: semantic_body should collapse")
	panel.semantic_header.pressed.emit()
	assert(panel.semantic_body.visible == true, "FAIL: semantic_body should expand")

	# Test DebugMargin accordion
	assert(panel.debug_header != null and panel.debug_body != null)
	panel.debug_header.pressed.emit()
	assert(panel.debug_body.visible == false, "FAIL: debug_body should collapse")
	panel.debug_header.pressed.emit()
	assert(panel.debug_body.visible == true, "FAIL: debug_body should expand")

	# Test CompositionMargin accordion
	assert(panel.composition_header != null and panel.composition_body != null)
	panel.composition_header.pressed.emit()
	assert(panel.composition_body.visible == false, "FAIL: composition_body should collapse")
	panel.composition_header.pressed.emit()
	assert(panel.composition_body.visible == true, "FAIL: composition_body should expand")

	# Test CompositionTuningMargin accordion
	assert(panel.comp_tuning_header != null and panel.comp_tuning_body != null)
	panel.comp_tuning_header.pressed.emit()
	assert(panel.comp_tuning_body.visible == false, "FAIL: comp_tuning_body should collapse")
	panel.comp_tuning_header.pressed.emit()
	assert(panel.comp_tuning_body.visible == true, "FAIL: comp_tuning_body should expand")

	# Test Advanced sub-accordion
	assert(panel.adv_tuning_header != null and panel.adv_tuning_body != null)
	assert(panel.adv_tuning_body.visible == false, "FAIL: adv_tuning_body should be collapsed by default")
	panel.adv_tuning_header.pressed.emit()
	assert(panel.adv_tuning_body.visible == true, "FAIL: adv_tuning_body should expand")
	panel.adv_tuning_header.pressed.emit()
	assert(panel.adv_tuning_body.visible == false, "FAIL: adv_tuning_body should collapse")

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] Accordions validated.")

func _test_composition_tuning_controls() -> void:
	print("\n[TEST 2] Testing initial values and ranges of Composition Tuning controls...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	assert(panel.get_composition_version() == 2, "FAIL: initial composition_version should be 2")
	assert(panel.get_preferred_progression_direction() == Vector2.ZERO, "FAIL: initial direction should be Vector2.ZERO")
	assert(is_equal_approx(panel.get_anchor_distance_strength(), 1.0), "FAIL: anchor_distance_strength default")
	assert(is_equal_approx(panel.get_neighbor_coherence_strength(), 1.0), "FAIL: neighbor_coherence_strength default")
	assert(is_equal_approx(panel.get_main_path_alignment_strength(), 1.0), "FAIL: main_path_alignment_strength default")
	assert(is_equal_approx(panel.get_branch_lateral_strength(), 0.75), "FAIL: branch_lateral_strength default")
	assert(is_equal_approx(panel.get_terminal_spacing_strength(), 0.75), "FAIL: terminal_spacing_strength default")
	assert(panel.get_composition_candidate_count() == 24, "FAIL: composition_candidate_count default")

	# Advanced
	assert(is_equal_approx(panel.get_preferred_distance(), 12.0), "FAIL: preferred_distance default")
	assert(is_equal_approx(panel.get_distance_jitter(), 4.0), "FAIL: distance_jitter default")
	assert(is_equal_approx(panel.get_density_strength(), 0.5), "FAIL: density_strength default")

	# Check slider ranges
	assert(panel.anchor_dist_slider.min_value == 0.0 and panel.anchor_dist_slider.max_value == 5.0)
	assert(panel.cand_count_slider.min_value == 8.0 and panel.cand_count_slider.max_value == 48.0)
	assert(panel.pref_dist_slider.min_value == 4.0 and panel.pref_dist_slider.max_value == 30.0)
	assert(panel.dist_jitter_slider.min_value == 0.0 and panel.dist_jitter_slider.max_value == 15.0)
	assert(panel.density_strength_slider.min_value == 0.0 and panel.density_strength_slider.max_value == 2.0)

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] Composition Tuning defaults and ranges validated.")

func _test_direction_buttons() -> void:
	print("\n[TEST 3] Testing direction buttons (Horizontal, Vertical, Diagonal, Random)...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	panel.btn_dir_horiz.pressed.emit()
	assert(panel.get_preferred_progression_direction() == Vector2(1, 0), "FAIL: horizontal direction")
	assert(panel.dir_status_label.text.find("HORIZONTAL") != -1)

	panel.btn_dir_vert.pressed.emit()
	assert(panel.get_preferred_progression_direction() == Vector2(0, 1), "FAIL: vertical direction")
	assert(panel.dir_status_label.text.find("VERTICAL") != -1)

	panel.btn_dir_diag.pressed.emit()
	var expected_diag = Vector2(1, 1).normalized()
	assert(panel.get_preferred_progression_direction().is_equal_approx(expected_diag), "FAIL: diagonal direction")
	assert(panel.dir_status_label.text.find("DIAGONAL") != -1)

	panel.btn_dir_rand.pressed.emit()
	assert(panel.get_preferred_progression_direction() == Vector2.ZERO, "FAIL: random direction")
	assert(panel.dir_status_label.text.find("RANDOM") != -1)

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] Direction buttons validated.")

func _test_slider_label_sync() -> void:
	print("\n[TEST 4] Testing real-time slider value label synchronization...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	panel.set_anchor_distance_strength(3.5)
	assert(panel.anchor_dist_val.text == "3.50", "FAIL: anchor_dist_val not synced")

	panel.set_composition_candidate_count(36)
	assert(panel.cand_count_val.text == "36", "FAIL: cand_count_val not synced")

	panel.set_preferred_distance(20.0)
	assert(panel.pref_dist_val.text == "20.0", "FAIL: pref_dist_val not synced")

	panel.set_distance_jitter(8.5)
	assert(panel.dist_jitter_val.text == "8.5", "FAIL: dist_jitter_val not synced")

	panel.set_density_strength(1.25)
	assert(panel.density_strength_val.text == "1.25", "FAIL: density_strength_val not synced")

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] Slider label synchronization validated.")

func _test_config_overrides() -> void:
	print("\n[TEST 5] Testing DungeonConfig & DungeonLabConfiguration overrides...")
	var panel = _LeftPanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	# Select version 1
	panel.set_composition_version(1)
	# Select Horizontal
	panel.set_progression_direction_mode("horizontal")
	# Change sliders
	panel.set_anchor_distance_strength(4.2)
	panel.set_neighbor_coherence_strength(2.8)
	panel.set_main_path_alignment_strength(3.1)
	panel.set_branch_lateral_strength(1.65)
	panel.set_terminal_spacing_strength(2.45)
	panel.set_composition_candidate_count(40)
	panel.set_preferred_distance(16.0)
	panel.set_distance_jitter(6.0)
	panel.set_density_strength(0.85)

	# Test apply_to_lab_config
	var lab_cfg = _LabConfigScript.new()
	panel.apply_to_lab_config(lab_cfg)

	assert(lab_cfg.composition_version == 1, "FAIL: lab_cfg composition_version")
	assert(lab_cfg.preferred_progression_direction == Vector2(1, 0), "FAIL: lab_cfg progression_direction")
	assert(is_equal_approx(lab_cfg.anchor_distance_strength, 4.2), "FAIL: lab_cfg anchor_distance_strength")
	assert(is_equal_approx(lab_cfg.neighbor_coherence_strength, 2.8), "FAIL: lab_cfg neighbor_coherence_strength")
	assert(is_equal_approx(lab_cfg.main_path_alignment_strength, 3.1), "FAIL: lab_cfg main_path_alignment_strength")
	assert(is_equal_approx(lab_cfg.branch_lateral_strength, 1.65), "FAIL: lab_cfg branch_lateral_strength")
	assert(is_equal_approx(lab_cfg.terminal_spacing_strength, 2.45), "FAIL: lab_cfg terminal_spacing_strength")
	assert(lab_cfg.composition_candidate_count == 40, "FAIL: lab_cfg composition_candidate_count")
	assert(is_equal_approx(lab_cfg.mission_aware_preferred_distance, 16.0), "FAIL: lab_cfg preferred_distance")
	assert(is_equal_approx(lab_cfg.mission_aware_distance_jitter, 6.0), "FAIL: lab_cfg distance_jitter")
	assert(is_equal_approx(lab_cfg.density_strength, 0.85), "FAIL: lab_cfg density_strength")

	# Test lab_cfg.to_dungeon_config()
	var d_cfg = lab_cfg.to_dungeon_config()
	assert(d_cfg.composition_version == 1, "FAIL: d_cfg composition_version")
	assert(d_cfg.preferred_progression_direction == Vector2(1, 0), "FAIL: d_cfg progression_direction")
	assert(is_equal_approx(d_cfg.anchor_distance_strength, 4.2), "FAIL: d_cfg anchor_distance_strength")
	assert(is_equal_approx(d_cfg.space_grammar_config.anchor_distance_strength, 4.2), "FAIL: sgc anchor_distance_strength")
	assert(d_cfg.composition_candidate_count == 40, "FAIL: d_cfg composition_candidate_count")
	assert(is_equal_approx(d_cfg.space_grammar_config.mission_aware_preferred_distance, 16.0), "FAIL: sgc preferred_distance")

	root.remove_child(panel)
	panel.queue_free()
	print("  [OK] Configuration overrides validated.")

func _test_lab_generation_with_overrides() -> void:
	print("\n[TEST 6] Testing live generation with UI overrides right before generate...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	var lp = lab.ui_left_panel
	assert(lp != null, "FAIL: ui_left_panel missing in lab")
	lp._ready()

	# Set custom tuning in UI
	lp.set_progression_direction_mode("vertical")
	lp.set_anchor_distance_strength(3.7)
	lp.set_composition_candidate_count(30)
	lp.set_density_strength(0.95)

	# Trigger generation
	lab.generate_current()

	# Verify lab.config has been updated with the UI values
	assert(lab.config.preferred_progression_direction == Vector2(0, 1), "FAIL: lab.config direction not updated")
	assert(is_equal_approx(lab.config.anchor_distance_strength, 3.7), "FAIL: lab.config anchor strength not updated")
	assert(lab.config.composition_candidate_count == 30, "FAIL: lab.config candidate count not updated")
	assert(is_equal_approx(lab.config.density_strength, 0.95), "FAIL: lab.config density strength not updated")

	var gen_d_cfg = lab.config.to_dungeon_config()
	assert(gen_d_cfg.preferred_progression_direction == Vector2(0, 1), "FAIL: gen_d_cfg direction mismatch")
	assert(is_equal_approx(gen_d_cfg.anchor_distance_strength, 3.7), "FAIL: gen_d_cfg anchor mismatch")
	assert(gen_d_cfg.composition_candidate_count == 30, "FAIL: gen_d_cfg candidate count mismatch")

	root.remove_child(lab)
	lab.queue_free()
	print("  [OK] Live generation with UI overrides validated.")
