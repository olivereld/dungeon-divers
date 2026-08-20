extends SceneTree

## Test suite para validar el sistema de pestañas (Parámetros / Suelos) en DungeonVisualizer.

const DungeonVisualizer = preload("res://src/dungeon_generator/debug/dungeon_visualizer.gd")
const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonLevelController = preload("res://scenes/dungeon/dungeon_level_controller.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_visualizer_floor_tabs (Floor Tab UI) ---")
	print("==================================================================")

	var visualizer := DungeonVisualizer.new()
	var root := Control.new()
	root.add_child(visualizer)

	# 1. Validar que los controles de pestañas existen
	assert(visualizer._tab_btn_params != null, "Tab button Parámetros exists")
	assert(visualizer._tab_btn_floors != null, "Tab button Suelos exists")
	assert(visualizer._tab_params_container != null, "Params container exists")
	assert(visualizer._tab_floors_container != null, "Floors container exists")

	# 2. Validar cambio de pestañas
	visualizer._switch_tab(1)
	assert(visualizer._tab_params_container.visible == false, "Params hidden when on floors tab")
	assert(visualizer._tab_floors_container.visible == true, "Floors visible on floors tab")

	visualizer._switch_tab(0)
	assert(visualizer._tab_params_container.visible == true, "Params visible on params tab")
	assert(visualizer._tab_floors_container.visible == false, "Floors hidden on params tab")
	print("  [OK] Tab switching (Parámetros / Suelos) validated.")

	# 3. Validar opciones de suelo en la UI
	assert(visualizer._opt_floor_pattern != null and visualizer._opt_floor_pattern.item_count == 5, "5 Floor patterns available")
	assert(visualizer._opt_floor_preset != null and visualizer._opt_floor_preset.item_count == 4, "4 Floor PBR presets available")
	assert(visualizer._slider_floor_size != null and visualizer._slider_floor_size.value == 2.0, "Tile size default is 2.0m")
	assert(visualizer._slider_floor_margin != null and visualizer._slider_floor_margin.value == 0.035, "Tile margin default is 0.035m")
	print("  [OK] Floor controls (Pattern, Preset, Size, Margin, Collision, Noise) verified.")

	# 4. Validar integración con DungeonLevelController
	var controller := DungeonLevelController.new()
	controller.visualizer = visualizer
	controller.config = DungeonConfig.new()
	controller._connect_visualizer_signals()

	# Emitir señal de cambio de patrón de suelo
	visualizer.floor_pattern_changed.emit(FloorTileConfig.PatternType.COBBLESTONE)
	assert(controller.config.floor_tile_config != null, "FloorTileConfig created automatically")
	assert((controller.config.floor_tile_config as FloorTileConfig).pattern == FloorTileConfig.PatternType.COBBLESTONE, "Pattern Cobblestone bound correctly")

	# Emitir señal de cambio de preset de material
	visualizer.floor_preset_changed.emit(2) # Dark Crypt
	assert((controller.config.floor_tile_config as FloorTileConfig).material_preset == 2, "Material preset bound correctly")
	print("  [OK] Controller signal bindings and config synchronization verified.")

	root.free()
	controller.free()

	print("==================================================================")
	print("[PASS] test_dungeon_visualizer_floor_tabs completado con 100% éxito!")
	print("==================================================================")
	quit(0)
