extends SceneTree

const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")

func _init() -> void:
	print("================================================================")
	print("   TEST INTEGRACION END-TO-END: DUNGEON LEVEL LAB (5 MODOS)    ")
	print("================================================================")

	var lab = _LabScene.instantiate()
	assert(lab != null, "FAIL: Could not instantiate dungeon_level_lab.tscn")
	root.add_child(lab)
	lab._ready()

	# 1. Mode: GENERATE (Single-Floor)
	print("1. Probando Modo GENERATE (1 Piso)...")
	lab.config.seed = 100001
	lab.config.generator_type = "Hybrid"
	lab.config.floor_count = 1
	lab.controller.generate_dungeon(lab.config)
	assert(lab.renderer.get_rendered_room_count() > 0, "FAIL: single floor generation failed")

	# 2. Mode: GENERATE (Multi-Floor)
	print("2. Probando Modo GENERATE (2 Pisos)...")
	lab.config.floor_count = 2
	var multi_res = lab.controller.generate_dungeon(lab.config)
	assert(multi_res.has("floors") and multi_res["floors"].size() == 2, "FAIL: multi-floor generation failed")

	# 3. Room Selection & Inspector
	print("3. Probando Selección e Inspector de Sala...")
	var first_floor = lab.controller.get_current_floor_result()
	var first_room = first_floor.rooms[0]
	lab._on_room_selected(first_room)
	assert(lab.inspector_text.text.find("ROOM #") != -1, "FAIL: inspector text not updated")

	# 4. Mode: SHOWCASE
	print("4. Probando Modo SHOWCASE (crypt)...")
	lab.current_mode = lab.LabMode.SHOWCASE
	lab._update_ui_for_mode()
	assert(lab.inspector_text.text.find("SHOWCASE: crypt") != -1, "FAIL: showcase text not updated")

	# 5. Mode: COVERAGE
	print("5. Probando Modo COVERAGE (10 Semillas)...")
	lab.current_mode = lab.LabMode.COVERAGE
	var cov_report = lab.run_coverage_mode(10)
	assert(cov_report["seed_count"] == 10, "FAIL: coverage report mismatch")
	assert(lab.inspector_text.text.find("COVERAGE REPORT") != -1, "FAIL: coverage text not updated")

	# 6. Mode: REGRESSION (Golden Fixtures)
	print("6. Probando Modo REGRESSION (20 Golden Seeds)...")
	lab.current_mode = lab.LabMode.REGRESSION
	var reg_report = lab.run_regression_mode()
	assert(reg_report["total_seeds"] == 20, "FAIL: regression total seeds mismatch")
	assert(reg_report["matched_seeds"] == 20, "FAIL: all 20 golden seeds must pass with 0 drift")
	assert(reg_report["mismatched_seeds"] == 0, "FAIL: no drift allowed")

	# 7. Error UI Path
	print("7. Probando Manejo de Error en Configuración Inválida...")
	var invalid_cfg = lab.config
	invalid_cfg.grid_size = Vector2i(0, 0)
	var err_res = lab.controller.generate_dungeon(invalid_cfg)
	assert(err_res.is_empty(), "FAIL: invalid config must fail cleanly")
	assert(lab.renderer.has_error_state(), "FAIL: renderer must display failure banner")

	print("\n>>> ALL 5 MODES IN DUNGEON LEVEL LAB PASSED 100%! <<<\n")
	lab.queue_free()
	quit(0)
