extends SceneTree

const DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_multifloor_integration ---")
	print("==================================================================")

	var level = DungeonLevelScene.instantiate()
	root.add_child(level)

	var cfg := DungeonConfigScript.new()
	cfg.dungeon_id = &"crypt_multifloor_level"
	cfg.seed = 133742
	cfg.use_fixed_seed = true
	cfg.grid_width = 48
	cfg.grid_height = 48
	cfg.total_floors = 3
	cfg.floor_height = 6.0
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	level.config = cfg

	# 1. Ejecutar regeneración lógica multi-piso
	level.regenerate(false)
	assert(level._current_multi_result != null, "FAIL: MultiFloor result must not be null")
	assert(level._current_multi_result.is_valid, "FAIL: MultiFloor result must be valid")
	assert(level._current_multi_result.get_floor_count() == 3, "FAIL: Must have 3 floors")
	assert(level._current_semantic_result != null, "FAIL: Initial semantic result must not be null")
	print("  [OK] 2D Multi-floor generation completed for 3 floors.")

	# 2. Materializar mundo 3D multi-piso
	level.build_3d_presentation()
	assert(level._current_presentation_root != null, "FAIL: 3D presentation root is null")
	assert(level._current_presentation_root.visible, "FAIL: 3D presentation root must be visible")
	assert(level._generation_state == "READY_3D", "FAIL: Generation state must be READY_3D")

	# 3. Validar presencia de Floor_0, Floor_1, Floor_2 con props, fixtures y escaleras
	var total_props: int = 0
	var total_fixtures: int = 0
	var total_stairs: int = 0

	for f_num in range(3):
		var f_node = level._current_presentation_root.get_node_or_null("Floor_%d" % f_num)
		assert(f_node != null, "FAIL: Floor_%d node must exist" % f_num)

		var floor_props: int = 0
		var floor_fixtures: int = 0
		var floor_stairs: int = 0

		for child in f_node.get_children():
			if child.name.begins_with("Prop_"):
				floor_props += 1
			elif child.name == "Fixtures":
				floor_fixtures += child.get_child_count()
			elif child.name == "Stairs":
				floor_stairs += child.get_child_count()

		assert(floor_props > 0, "FAIL: Floor_%d must contain materialized props" % f_num)
		assert(floor_fixtures > 0, "FAIL: Floor_%d must contain materialized fixtures" % f_num)
		assert(floor_stairs > 0, "FAIL: Floor_%d must contain materialized stairs" % f_num)

		total_props += floor_props
		total_fixtures += floor_fixtures
		total_stairs += floor_stairs
		print("  [OK] Floor_%d: %d props, %d fixtures, %d stairs." % [f_num, floor_props, floor_fixtures, floor_stairs])

	print("  [OK] Total Multi-Floor: %d props, %d fixtures, %d stairs across 3 floors." % [total_props, total_fixtures, total_stairs])

	# 4. Probar aislamiento de piso (Floor isolation mode)
	level._on_floor_view_mode_changed(1)
	assert(level._current_isolated_floor == 1, "FAIL: Isolated floor must be 1")
	var f0 = level._current_presentation_root.get_node_or_null("Floor_0")
	var f1 = level._current_presentation_root.get_node_or_null("Floor_1")
	var f2 = level._current_presentation_root.get_node_or_null("Floor_2")
	assert(not f0.visible, "FAIL: Floor 0 should be hidden when isolating Floor 1")
	assert(f1.visible, "FAIL: Floor 1 should be visible")
	assert(not f2.visible, "FAIL: Floor 2 should be hidden when isolating Floor 1")
	print("  [OK] Floor isolation mode verified.")

	# 5. Volver a vista de todos los pisos (-1)
	level._on_floor_view_mode_changed(-1)
	assert(f0.visible and f1.visible and f2.visible, "FAIL: All floors must be visible in mode -1")
	print("  [OK] Full multi-floor visibility restored.")

	level.queue_free()
	print("[PASS] test_dungeon_level_multifloor_integration completed successfully!")
	quit(0)
