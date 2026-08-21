extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_archetype_pipeline ---")
	print("==================================================================")

	var config := DungeonConfigScript.new()
	config.seed = 445566
	config.dungeon_archetype = DungeonArchetypeScript.Type.FORTRESS

	var pipeline := DungeonPipelineScript.new()
	var result = pipeline.generate(config)
	assert(result != null and result.grid != null, "FAIL: Dungeon generation must succeed with valid grid")

	var orchestrator := SemanticOrchestratorScript.new()
	var semantic_res = orchestrator.generate_semantics(result, config)

	assert(semantic_res != null and semantic_res.gameplay_valid, "FAIL: Semantic result must be valid")
	assert(semantic_res.dungeon_archetype == DungeonArchetypeScript.Type.FORTRESS)
	assert(semantic_res.dungeon_archetype_name == "FORTRESS")
	assert(semantic_res.room_purposes.size() == result.rooms.size(), "FAIL: Every room must have a purpose")

	var boss_purpose = semantic_res.get_room_purpose(semantic_res.boss_room_id)
	assert(boss_purpose == RoomPurposeScript.Type.THRONE_ROOM, "FAIL: Fortress boss must be THRONE_ROOM")

	# Test Inmutabilidad: Probar que la misma semilla con MAUSOLEUM produce distinta semántica pero MISMA geometría de CellGrid
	var config_m := config.duplicate_config()
	config_m.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	var result_m = pipeline.generate(config_m)
	var semantic_res_m = orchestrator.generate_semantics(result_m, config_m)

	assert(semantic_res_m.dungeon_archetype == DungeonArchetypeScript.Type.MAUSOLEUM)
	var boss_purpose_m = semantic_res_m.get_room_purpose(semantic_res_m.boss_room_id)
	assert(boss_purpose_m == RoomPurposeScript.Type.ROYAL_TOMB or boss_purpose_m == RoomPurposeScript.Type.SANCTUM)

	# Comprobar inmutabilidad geométrica
	assert(result.grid.width == result_m.grid.width and result.grid.height == result_m.grid.height)
	assert(result.rooms.size() == result_m.rooms.size())

	print("  [OK] Pipeline integration verified for FORTRESS and MAUSOLEUM.")
	print("  [OK] Geometric immutability verified.")
	print("[PASS] test_dungeon_archetype_pipeline completed successfully.")
	quit(0)
