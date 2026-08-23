extends SceneTree

## Test unitario para el flujo de prueba por pasos (Plano 2D -> Generación 3D).

func _init() -> void:
	print("--- Running test_dungeon_2d_3d_flow ---")
	var VisualizerScript = preload("res://src/dungeon_generator/debug/dungeon_visualizer.gd")
	var ControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")

	var visualizer = VisualizerScript.new()
	var controller = ControllerScript.new()

	controller.visualizer = visualizer
	controller._connect_visualizer_signals()

	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.seed = 812297351
	config.use_fixed_seed = true

	var res = pipeline.generate(config, 5, false)
	assert(res != null, "Pipeline generation must succeed")

	# 1. Probar que visualizer inicia en modo Preview 2D
	visualizer.show_2d_preview(res)
	assert(visualizer.is_2d_preview_mode == true, "Visualizer must be in 2D preview mode")
	print("  [OK] 2D preview mode activated")

	# 2. Probar cambio a modo 3D
	visualizer.hide_2d_preview()
	assert(visualizer.is_2d_preview_mode == false, "Visualizer must switch to 3D mode")
	print("  [OK] 3D mode transition verified")

	# 3. Probar modo Multi-Floor 2D
	var MultiFloorGenScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
	var multi_gen = MultiFloorGenScript.new()
	config.total_floors = 3
	var multi_res = multi_gen.generate_multi_floor(config)
	assert(multi_res != null and multi_res.is_valid, "Multi-floor generation must succeed")

	# 4. Probar que cambiar el selector de piso en 3D NO activa el modo 2D
	visualizer.hide_2d_preview()
	assert(visualizer.is_2d_preview_mode == false)
	controller._on_floor_view_mode_changed(1)
	assert(visualizer.is_2d_preview_mode == false, "Changing floor in 3D must stay in 3D mode")
	print("  [OK] Floor isolation in 3D preserves 3D navigation mode")

	# 5. Probar toggle de paredes y puertas
	visualizer.walls_visibility_toggled.emit(false)
	assert(controller._are_walls_visible == false, "Walls visibility signal must toggle controller state")
	print("  [OK] Walls visibility toggle verified")

	visualizer.doors_visibility_toggled.emit(false)
	assert(controller._are_doors_visible == false, "Doors visibility signal must toggle controller state")
	print("  [OK] Doors visibility toggle verified")

	print("[PASS] test_dungeon_2d_3d_flow completed successfully!")
	quit(0)
