extends SceneTree

const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")
const _ControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")
const _ConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _FloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")

func _init() -> void:
	print("================================================================")
	print("   TEST: LAB SYNCHRONIZATION, ASCII REFACTOR & EXTENDED OVERLAYS")
	print("================================================================")

	_test_1_lab_controller_adapter()
	_test_2_ascii_export_reuse()
	_test_3_overlay_properties_and_renderer_methods()
	_test_4_multi_seed_consistency()
	_test_5_no_dungeon_archetype_guard()

	print("\n>>> ALL LAB SYNCHRONIZATION TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)

func _test_1_lab_controller_adapter() -> void:
	print("\n[TEST 1] Verificando DungeonLabController adaptador from_dungeon_result()...")
	var ctrl = _ControllerScript.new()
	var cfg = _ConfigScript.new()
	cfg.seed = 424242
	cfg.floor_count = 1
	cfg.archetype_id = "standard"

	var res: Dictionary = ctrl.generate_dungeon(cfg)
	assert(res.has("dungeon_result"), "FAIL: result must have dungeon_result")
	assert(res.has("floors") and res["floors"].size() > 0, "FAIL: result must have floors")

	var orig_res: DungeonResult = res["dungeon_result"]
	var f_data = res["floors"][0]

	assert(f_data != null, "FAIL: floor_data must not be null")
	assert(f_data.floor_number >= 1, "FAIL: floor_number must be >= 1, got %d" % f_data.floor_number)
	assert(f_data.seed_used == orig_res.seed_used, "FAIL: seed_used mismatch")
	assert(f_data.rooms.size() == orig_res.rooms.size(), "FAIL: rooms count mismatch")
	assert(f_data.connections.size() == orig_res.connections.size(), "FAIL: connections count mismatch")
	assert(f_data.corridor_paths.size() == orig_res.corridor_paths.size(), "FAIL: corridor_paths count mismatch")
	assert(f_data.door_pairs.size() == orig_res.door_pairs.size(), "FAIL: door_pairs count mismatch")
	assert(f_data.metadata == orig_res.metadata, "FAIL: metadata mismatch")
	assert(f_data.semantic_result != null, "FAIL: semantic_result should be attached")
	print("  [OK] DungeonFloorData correctamente adaptado via from_dungeon_result con todos los campos.")

func _test_2_ascii_export_reuse() -> void:
	print("\n[TEST 2] Verificando _on_copy_ascii_pressed() y reutilización de DungeonResult...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	lab.config.seed = 100200
	lab.config.floor_count = 1
	lab.controller.generate_dungeon(lab.config)

	var cur_res = lab.controller.get_current_result()
	var orig_d_result = cur_res["dungeon_result"]
	assert(orig_d_result != null, "FAIL: orig_d_result must exist")

	# Llamar _on_copy_ascii_pressed()
	lab._on_copy_ascii_pressed()
	assert(lab.status_label.text.find("copiado") != -1, "FAIL: status should indicate copy success")
	print("  [OK] ASCII export ejecutado con éxito reutilizando DungeonResult original.")

	# Probar fallback explícito cuando d_result original no está en controller
	lab.controller._current_result.erase("dungeon_result")
	lab._on_copy_ascii_pressed()
	assert(lab.status_label.text.find("copiado") != -1, "FAIL: fallback copy should also succeed")
	print("  [OK] Fallback explícito de exportación ASCII verificado exitosamente.")

	lab.queue_free()

func _test_3_overlay_properties_and_renderer_methods() -> void:
	print("\n[TEST 3] Verificando reactividad de Overlays y métodos del Renderer...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	var overlay = lab.overlay
	var changed: Array = [0]
	overlay.overlay_changed.connect(func(): changed[0] += 1)

	assert("show_spatial_overlay" in overlay, "FAIL: show_spatial_overlay missing in overlay")
	assert("show_corridor_details" in overlay, "FAIL: show_corridor_details missing in overlay")
	assert("show_semantics_overlay" in overlay, "FAIL: show_semantics_overlay missing in overlay")

	overlay.show_spatial_overlay = true
	assert(changed[0] == 1, "FAIL: show_spatial_overlay did not emit overlay_changed, changed[0]=%d" % changed[0])

	overlay.show_corridor_details = true
	assert(changed[0] == 2, "FAIL: show_corridor_details did not emit overlay_changed")

	overlay.show_semantics_overlay = true
	assert(changed[0] == 3, "FAIL: show_semantics_overlay did not emit overlay_changed")

	var renderer = lab.renderer
	assert(renderer.has_method("_draw_corridors_overlay"), "FAIL: renderer missing _draw_corridors_overlay")
	assert(renderer.has_method("_draw_spatial_overlay"), "FAIL: renderer missing _draw_spatial_overlay")
	assert(renderer.has_method("_draw_semantics_overlay"), "FAIL: renderer missing _draw_semantics_overlay")
	print("  [OK] Propiedades de overlay reactivas y métodos de dibujo presentes en Renderer.")

	lab.queue_free()

func _test_4_multi_seed_consistency() -> void:
	print("\n[TEST 4] Verificando consistencia a través de múltiples semillas...")
	var ctrl = _ControllerScript.new()
	var cfg = _ConfigScript.new()
	cfg.floor_count = 1
	var test_seeds = [11111, 22222, 33333, 77777, 98765]

	for s in test_seeds:
		cfg.seed = s
		var res = ctrl.generate_dungeon(cfg)
		var orig = res.get("dungeon_result")
		var floors = res.get("floors", [])
		var fd = floors[0] if floors.size() > 0 else null
		assert(orig != null and fd != null, "FAIL: generation failed for seed %d" % s)
		assert(fd.corridor_paths.size() == orig.corridor_paths.size(), "FAIL: corridor_paths mismatch seed %d" % s)
		assert(fd.connections.size() == orig.connections.size(), "FAIL: connections mismatch seed %d" % s)
		assert(fd.door_pairs.size() == orig.door_pairs.size(), "FAIL: door_pairs mismatch seed %d" % s)
		print("  -> Seed %d: %d rooms, %d connections, %d corridor paths [PASSED]" % [
			s, fd.rooms.size(), fd.connections.size(), fd.corridor_paths.size()
		])

func _test_5_no_dungeon_archetype_guard() -> void:
	print("\n[TEST 5] Verificando ausencia de 'dungeon_archetype' en código del Lab...")
	var dir = DirAccess.open("res://src/dungeon_generator/debug/lab")
	assert(dir != null, "FAIL: could not open lab dir")
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			var file_path = "res://src/dungeon_generator/debug/lab/" + f
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var content = file.get_as_text()
				file.close()
				assert(content.find("dungeon_archetype") == -1, "FAIL: forbidden 'dungeon_archetype' found in %s" % f)
		f = dir.get_next()
	print("  [OK] Ningún archivo en debug/lab contiene 'dungeon_archetype'.")
