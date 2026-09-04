extends SceneTree

# Test de Verificación: Nuevos Overlays de Composición y Visualización en Inspector

const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")
const _ControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")
const _InspectorScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _RendererScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd")
const _ConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")

func _init() -> void:
	print("--- Running test_composition_overlays_and_inspector ---")
	
	_test_1_overlay_state_and_reactivity()
	_test_2_inspector_composition_fields()
	_test_3_anchors_timing_modes()
	_test_4_lab_integration_and_pipeline_data()
	
	print("[PASS] All composition overlay and inspector tests passed successfully!")
	quit()

func _test_1_overlay_state_and_reactivity() -> void:
	print("\n[TEST 1] Verificando los 5 nuevos overlays y reactividad...")
	var overlay := _OverlayScript.new()
	var signal_count: Array = [0]
	overlay.overlay_changed.connect(func(): signal_count[0] += 1)

	# 1. Composition Anchors
	assert("show_composition_anchors" in overlay, "Overlay must have show_composition_anchors")
	overlay.show_composition_anchors = true
	assert(overlay.show_composition_anchors == true, "show_composition_anchors should be true")
	assert(signal_count[0] == 1, "show_composition_anchors should emit overlay_changed")

	# 2. Progression Axis
	assert("show_progression_axis" in overlay, "Overlay must have show_progression_axis")
	overlay.show_progression_axis = true
	assert(overlay.show_progression_axis == true, "show_progression_axis should be true")
	assert(signal_count[0] == 2, "show_progression_axis should emit overlay_changed")

	# 3. Main Path Composition
	assert("show_main_path_composition" in overlay, "Overlay must have show_main_path_composition")
	overlay.show_main_path_composition = true
	assert(overlay.show_main_path_composition == true, "show_main_path_composition should be true")
	assert(signal_count[0] == 3, "show_main_path_composition should emit overlay_changed")

	# 4. Branch Zones
	assert("show_branch_zones" in overlay, "Overlay must have show_branch_zones")
	overlay.show_branch_zones = true
	assert(overlay.show_branch_zones == true, "show_branch_zones should be true")
	assert(signal_count[0] == 4, "show_branch_zones should emit overlay_changed")

	# 5. Density Zones
	assert("show_density_zones" in overlay, "Overlay must have show_density_zones")
	overlay.show_density_zones = true
	assert(overlay.show_density_zones == true, "show_density_zones should be true")
	assert(signal_count[0] == 5, "show_density_zones should emit overlay_changed")

	# Verificar que overlays existentes se preservan
	assert(overlay.show_room_bounds == true, "show_room_bounds must remain functional")
	assert(overlay.show_template_footprint == true, "show_template_footprint must remain functional")
	assert(overlay.show_corridors == true, "show_corridors must remain functional")
	assert(overlay.show_entrances == true, "show_entrances must remain functional")
	assert(overlay.show_stairs == true, "show_stairs must remain functional")

	print("  -> Passed overlay reactivity verification.")

func _test_2_inspector_composition_fields() -> void:
	print("\n[TEST 2] Verificando campos de composición en DungeonLabInspector...")
	var ctrl := _ControllerScript.new()
	var cfg := _ConfigScript.new()
	cfg.seed = 2026
	cfg.grid_size = Vector2i(64, 64)
	cfg.floor_count = 1

	var res_dict = ctrl.generate_dungeon(cfg)
	assert(not res_dict.is_empty(), "Dungeon generation should succeed")

	var floor_res = ctrl.get_current_floor_result()
	assert(floor_res != null, "Floor result should exist")
	assert(floor_res.spatial_composition != null, "spatial_composition must exist on floor result")

	var inspector := _InspectorScript.new()
	var bundle = ctrl.get_profile_bundle()

	for room in floor_res.rooms:
		var diag: Dictionary = inspector.inspect_room(room, bundle, cfg.seed, [], floor_res.spatial_composition)
		
		# Verificación estricta de los 6 campos requeridos por especificación
		assert(diag.has("composition_region"), "Inspector must contain composition_region")
		assert(diag.has("progression_factor"), "Inspector must contain progression_factor")
		assert(diag.has("anchor_position"), "Inspector must contain anchor_position")
		assert(diag.has("density"), "Inspector must contain density")
		assert(diag.has("main_path"), "Inspector must contain main_path")
		assert(diag.has("branch_anchor"), "Inspector must contain branch_anchor")

		assert(diag["composition_region"] is StringName or diag["composition_region"] is String, "composition_region must be a valid name")
		assert(diag["progression_factor"] is float, "progression_factor must be a float")
		assert(diag["anchor_position"] is Vector2, "anchor_position must be a Vector2")
		assert(diag["density"] is float, "density must be a float")
		assert(diag["main_path"] is bool, "main_path must be a bool")
		assert(diag["branch_anchor"] is int, "branch_anchor must be an int")

	print("  -> Passed inspector composition fields verification on %d rooms." % floor_res.rooms.size())

func _test_3_anchors_timing_modes() -> void:
	print("\n[TEST 3] Verificando modos de visualización de anclas antes/después...")
	var overlay := _OverlayScript.new()
	assert("anchors_timing_mode" in overlay, "Overlay must have anchors_timing_mode")

	overlay.anchors_timing_mode = &"before"
	assert(overlay.anchors_timing_mode == &"before", "Timing mode should be 'before'")

	overlay.anchors_timing_mode = &"after"
	assert(overlay.anchors_timing_mode == &"after", "Timing mode should be 'after'")

	overlay.anchors_timing_mode = &"both"
	assert(overlay.anchors_timing_mode == &"both", "Timing mode should be 'both'")

	print("  -> Passed anchors timing mode verification.")

func _test_4_lab_integration_and_pipeline_data() -> void:
	print("\n[TEST 4] Verificando integración con DungeonLevelLab sin lógica de generación en Lab...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	# Probar toggle de cada nuevo overlay via _on_overlay_toggled
	lab._on_overlay_toggled("composition_anchors", true)
	assert(lab.overlay.show_composition_anchors == true, "Lab should toggle composition_anchors")

	lab._on_overlay_toggled("progression_axis", true)
	assert(lab.overlay.show_progression_axis == true, "Lab should toggle progression_axis")

	lab._on_overlay_toggled("main_path_composition", true)
	assert(lab.overlay.show_main_path_composition == true, "Lab should toggle main_path_composition")

	lab._on_overlay_toggled("branch_zones", true)
	assert(lab.overlay.show_branch_zones == true, "Lab should toggle branch_zones")

	lab._on_overlay_toggled("density_zones", true)
	assert(lab.overlay.show_density_zones == true, "Lab should toggle density_zones")

	# Probar cambio de modo timing de anclas
	lab.set_anchors_timing_mode(&"before")
	assert(lab.overlay.anchors_timing_mode == &"before", "Lab should set anchors_timing_mode to before")
	lab.set_anchors_timing_mode(&"after")
	assert(lab.overlay.anchors_timing_mode == &"after", "Lab should set anchors_timing_mode to after")
	lab.set_anchors_timing_mode(&"both")
	assert(lab.overlay.anchors_timing_mode == &"both", "Lab should set anchors_timing_mode to both")

	# Renderer draw methods
	assert(lab.renderer.has_method("_draw_composition_anchors_overlay"), "Renderer must have _draw_composition_anchors_overlay")
	assert(lab.renderer.has_method("_draw_progression_axis_overlay"), "Renderer must have _draw_progression_axis_overlay")
	assert(lab.renderer.has_method("_draw_main_path_composition_overlay"), "Renderer must have _draw_main_path_composition_overlay")
	assert(lab.renderer.has_method("_draw_branch_zones_overlay"), "Renderer must have _draw_branch_zones_overlay")
	assert(lab.renderer.has_method("_draw_density_zones_overlay"), "Renderer must have _draw_density_zones_overlay")

	lab.queue_free()
	print("  -> Passed DungeonLevelLab integration verification.")
