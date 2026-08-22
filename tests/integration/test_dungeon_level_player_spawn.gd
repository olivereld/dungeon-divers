extends SceneTree

const DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_player_spawn ---")
	print("==================================================================")

	var level = DungeonLevelScene.instantiate()
	root.add_child(level)

	var cfg := DungeonConfigScript.new()
	cfg.dungeon_id = &"crypt_spawn_test"
	cfg.seed = 112233
	cfg.use_fixed_seed = true
	cfg.grid_width = 36
	cfg.grid_height = 36
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	level.config = cfg

	level.regenerate(false)
	level.build_3d_presentation()

	assert(level._player != null, "FAIL: Player is null")

	var cell_size: float = cfg.cell_size
	var player_cell := Vector2i(
		int(floor(level._player.global_position.x / cell_size)),
		int(floor(level._player.global_position.z / cell_size))
	)

	# 1. Comprobar que el jugador está dentro de alguna sala
	var found_room = false
	for room in level._current_semantic_result.rooms:
		if room.rect.has_point(player_cell):
			found_room = true
			break

	assert(found_room, "FAIL: Player spawned outside room bounds at cell %s" % str(player_cell))
	print("  [OK] Player is safely positioned inside a room at cell: %s." % str(player_cell))

	# 2. Comprobar que no está en las celdas reservadas de puertas
	var is_in_door = false
	for dp in level._current_semantic_result.door_pairs:
		if (dp.door_a != null and dp.door_a.position == player_cell) or (dp.door_b != null and dp.door_b.position == player_cell):
			is_in_door = true
			break

	assert(not is_in_door, "FAIL: Player spawned on a door cell")
	print("  [OK] Player spawn is clear of door transitions.")

	level.queue_free()
	print("[PASS] test_dungeon_level_player_spawn completed successfully!")
	quit(0)
