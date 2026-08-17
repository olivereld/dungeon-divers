class_name TestSeedInputUI
extends SceneTree

func _init() -> void:
	print("--- Running test_seed_input_ui ---")

	var controller_scene = preload("res://scenes/dungeon/dungeon_level.tscn")
	var controller: DungeonLevelController = controller_scene.instantiate()
	root.add_child(controller)
	controller.regenerate(false)

	assert(controller.visualizer != null, "Visualizer must exist")
	var vis: DungeonVisualizer = controller.visualizer
	assert(vis._seed_line_edit != null, "Seed LineEdit must be instantiated")
	assert(vis._btn_generate != null, "Generate button must exist")
	assert(vis._btn_random != null, "Random button must exist")
	assert(vis._btn_copy != null, "Copy button must exist")
	print("  [OK] Test 1: UI Controls (LineEdit, Generate, Random, Copy) successfully instantiated")

	# Test 2: Ingrese semilla numérica específica
	vis._apply_seed_input("12345")
	assert(controller.config.seed == 12345, "Config seed must be 12345")
	assert(controller.config.use_fixed_seed == true, "use_fixed_seed must be true")
	assert(controller._current_result.seed_used == 12345, "DungeonResult must have seed 12345")
	assert(vis._seed_line_edit.text == "12345", "LineEdit must display 12345")
	print("  [OK] Test 2: Numeric seed '12345' directly applied and generated deterministically")

	# Test 3: Ingrese semilla en forma de texto/palabra clave
	var custom_text := "dungeon_master_seed"
	var expected_hash: int = custom_text.hash()
	vis._apply_seed_input(custom_text)
	assert(controller.config.seed == expected_hash, "String seed must hash into integer seed")
	assert(controller._current_result.seed_used == expected_hash, "DungeonResult must match string hash seed")
	assert(vis._seed_line_edit.text == str(expected_hash), "LineEdit must reflect the active hashed seed")
	print("  [OK] Test 3: String seed '%s' successfully hashed to %d and generated" % [custom_text, expected_hash])

	# Test 4: Botón de Semilla Aleatoria
	var prev_seed = controller._current_result.seed_used
	vis._on_random_pressed()
	var new_seed = controller._current_result.seed_used
	assert(vis._seed_line_edit.text == str(new_seed), "LineEdit must update to the new random seed")
	print("  [OK] Test 4: Random seed button rolled new seed: %d (was: %d)" % [new_seed, prev_seed])

	# Test 5: Botón de Copiar al portapapeles
	vis._seed_line_edit.text = "99887766"
	vis._on_copy_pressed()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		var clipboard_val := DisplayServer.clipboard_get()
		assert(clipboard_val == "99887766", "Clipboard must contain copied seed")
	print("  [OK] Test 5: Seed copy action triggered cleanly")

	print("[PASS] test_seed_input_ui completed successfully with 100% assertions passing!")
	quit(0)
