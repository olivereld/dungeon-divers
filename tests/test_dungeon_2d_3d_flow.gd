extends SceneTree

## Test unitario para el flujo de prueba por pasos (Plano 2D -> Generación 3D).

func _init() -> void:
	print("--- Running test_dungeon_2d_3d_flow ---")
	var VisualizerScript = preload("res://src/dungeon_generator/debug/dungeon_visualizer.gd")
	var ControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")

	var visualizer = VisualizerScript.new()
	var controller = ControllerScript.new()

	controller.visualizer = visualizer

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

	print("[PASS] test_dungeon_2d_3d_flow completed successfully!")
	quit(0)
