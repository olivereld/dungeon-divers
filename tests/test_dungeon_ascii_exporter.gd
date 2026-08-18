extends SceneTree

## Test unitario para la exportación de planos a formato texto/ASCII (DungeonAsciiExporter).

func _init() -> void:
	print("--- Running test_dungeon_ascii_exporter ---")
	var ExporterScript = preload("res://src/dungeon_generator/debug/dungeon_ascii_exporter.gd")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.seed = 812297351
	config.use_fixed_seed = true

	var res = pipeline.generate(config, 5, false)
	assert(res != null, "Pipeline generation must succeed")

	var ascii_output: String = ExporterScript.export_ascii(res, null, true)
	assert(not ascii_output.is_empty(), "ASCII output must not be empty")
	assert(ascii_output.contains("=== DUNGEON ASCII MAP ==="), "Must contain ASCII header")
	assert(ascii_output.contains("Semilla: 812297351"), "Must contain seed")
	assert(ascii_output.contains("Salas:"), "Must list rooms")

	print("Generated ASCII output preview:\n" + ascii_output.substr(0, 400) + "...\n")
	print("[PASS] test_dungeon_ascii_exporter completed successfully!")
	quit(0)
