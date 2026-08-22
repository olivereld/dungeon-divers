extends SceneTree

const DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_determinism ---")
	print("==================================================================")

	var level = DungeonLevelScene.instantiate()
	root.add_child(level)

	var fixed_seed: int = 987654

	# Corrida 1
	var cfg1 := DungeonConfigScript.new()
	cfg1.dungeon_id = &"crypt_det_1"
	cfg1.seed = fixed_seed
	cfg1.use_fixed_seed = true
	cfg1.grid_width = 36
	cfg1.grid_height = 36
	cfg1.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	level.config = cfg1

	level.regenerate(false)
	level.build_3d_presentation()

	var rooms_1 = level._current_semantic_result.rooms.size()
	var player_pos_1 = level._player.position
	var prop_count_1: int = 0
	var fixture_count_1: int = 0
	for child in level._current_presentation_root.get_children():
		if child.name.begins_with("Prop_"):
			prop_count_1 += 1
		elif child.name == "Fixtures":
			fixture_count_1 += child.get_child_count()

	# Corrida 2 con exactamente la misma semilla
	var cfg2 := DungeonConfigScript.new()
	cfg2.dungeon_id = &"crypt_det_2"
	cfg2.seed = fixed_seed
	cfg2.use_fixed_seed = true
	cfg2.grid_width = 36
	cfg2.grid_height = 36
	cfg2.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	level.config = cfg2

	level.regenerate(false)
	level.build_3d_presentation()

	var rooms_2 = level._current_semantic_result.rooms.size()
	var player_pos_2 = level._player.position
	var prop_count_2: int = 0
	var fixture_count_2: int = 0
	for child in level._current_presentation_root.get_children():
		if child.name.begins_with("Prop_"):
			prop_count_2 += 1
		elif child.name == "Fixtures":
			fixture_count_2 += child.get_child_count()

	assert(rooms_1 == rooms_2, "FAIL: Room count mismatch across identical runs")
	assert(player_pos_1 == player_pos_2, "FAIL: Player spawn position mismatch")
	assert(prop_count_1 == prop_count_2, "FAIL: Prop count mismatch")
	assert(fixture_count_1 == fixture_count_2, "FAIL: Fixture count mismatch")

	print("  [OK] Absolute bit-by-bit determinism verified in full Dungeon Level.")
	print("  [OK] Rooms: %d, Props: %d, Fixtures: %d, Player Spawn: %s." % [rooms_1, prop_count_1, fixture_count_1, str(player_pos_1)])

	level.queue_free()
	print("[PASS] test_dungeon_level_determinism completed successfully!")
	quit(0)
