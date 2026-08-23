extends SceneTree

## Test suite para validar las métricas de composición espacial en el Debug Overlay (F3).

const DungeonLevelControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_debug_overlay_metrics ---")
	print("==================================================================")

	var controller = DungeonLevelControllerScript.new()
	var config := DungeonConfigScript.new()
	config.seed = 1337
	config.use_fixed_seed = true
	config.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	controller.config = config

	# Simular inicialización
	controller._setup_debug_overlay()
	controller.regenerate(false)

	assert(controller._debug_overlay_label != null, "FAIL: Debug overlay label must exist")

	controller._update_debug_overlay()
	var text: String = controller._debug_overlay_label.text

	assert(text.contains("DUNGEON DEBUG (F3)"), "FAIL: Overlay must contain header")
	assert(text.contains("CRYPT"), "FAIL: Overlay must display CRYPT archetype")
	assert(text.contains("Decoration:"), "FAIL: Overlay must contain decoration summary")

	print("  [OK] Debug overlay composition metrics successfully formatted.")

	controller.free()

	print("==================================================================")
	print("[PASS] test_composition_debug_overlay_metrics completado con 100% éxito!")
	print("==================================================================")
	quit(0)
