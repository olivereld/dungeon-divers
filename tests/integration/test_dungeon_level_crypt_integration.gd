extends SceneTree

const DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_crypt_integration ---")
	print("==================================================================")

	var level = DungeonLevelScene.instantiate()
	root.add_child(level)

	var cfg := DungeonConfigScript.new()
	cfg.dungeon_id = &"crypt_integration_level"
	cfg.seed = 45678
	cfg.use_fixed_seed = true
	cfg.grid_width = 36
	cfg.grid_height = 36
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	level.config = cfg

	# 1. Ejecutar regeneración lógica (2D preview)
	level.regenerate(false)
	assert(level._current_result != null, "FAIL: Layout generation failed")
	assert(level._current_semantic_result != null, "FAIL: Semantic generation failed")
	print("  [OK] 2D semantic generation completed in %.1fms." % (level._time_layout_ms + level._time_semantic_ms))

	# 2. Materializar mundo 3D
	level.build_3d_presentation()
	assert(level._current_presentation_root != null, "FAIL: 3D presentation root is null")
	assert(level._current_presentation_root.visible, "FAIL: 3D presentation root must be visible")
	assert(level._generation_state == "READY_3D", "FAIL: Generation state must be READY_3D")
	print("  [OK] 3D world presentation materialized in %.1fms." % level._time_presentation_ms)

	# 3. Validar presencia de props y fixtures
	var prop_count: int = 0
	var fixture_count: int = 0
	for child in level._current_presentation_root.get_children():
		if child.name.begins_with("Prop_"):
			prop_count += 1
		elif child.name == "Fixtures":
			fixture_count += child.get_child_count()

	assert(prop_count > 0, "FAIL: Expected props in 3D level")
	assert(fixture_count > 0, "FAIL: Expected fixtures in 3D level")
	print("  [OK] Materialized %d props and %d fixtures in level." % [prop_count, fixture_count])

	# 4. Validar spawn del jugador
	assert(level._player != null, "FAIL: Player test instance is null")
	assert(level._player.position != Vector3.ZERO, "FAIL: Player should not be at (0,0,0)")
	print("  [OK] Player spawned safely at: %s." % str(level._player.position))

	# 5. Probar activación de debug overlay (F3)
	level._toggle_debug_overlay()
	assert(level._debug_overlay_visible, "FAIL: Debug overlay must be visible")
	level._update_debug_overlay()
	assert(level._debug_overlay_label.text != "", "FAIL: Debug overlay label text must be populated")
	print("  [OK] F3 Debug Overlay verified.")

	level.queue_free()
	print("[PASS] test_dungeon_level_crypt_integration completed successfully!")
	quit(0)
