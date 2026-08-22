extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchetypeProfileFactoryScript = preload("res://src/dungeon_generator/core/semantic/archetype/archetype_profile_factory.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_archetype_semantics ---")
	print("==================================================================")

	# Test A: Validación de integridad de todos los perfiles
	for arch in [
		DungeonArchetypeScript.Type.GENERIC,
		DungeonArchetypeScript.Type.MAUSOLEUM,
		DungeonArchetypeScript.Type.FORTRESS,
		DungeonArchetypeScript.Type.TEMPLE,
		DungeonArchetypeScript.Type.MINE
	]:
		var p = ArchetypeProfileFactoryScript.get_profile(arch)
		assert(p != null and not p.purpose_weights.is_empty(), "FAIL: Profile weights cannot be empty")

	# Test B: Incompatibilidades estrictas en generación completa
	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()

	var arch_seeds = [1111, 2222, 3333, 4444]
	for s in arch_seeds:
		# MAUSOLEUM no debe contener ARMORY ni FORGE
		var cfg_m := DungeonConfigScript.new()
		cfg_m.seed = s
		cfg_m.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
		var res_m = pipeline.generate(cfg_m)
		var sem_m = orchestrator.generate_semantics(res_m, cfg_m)

		for r_id in sem_m.room_purposes:
			var p = sem_m.room_purposes[r_id]
			assert(p != RoomPurposeScript.Type.ARMORY, "FAIL: MAUSOLEUM cannot have ARMORY")
			assert(p != RoomPurposeScript.Type.FORGE, "FAIL: MAUSOLEUM cannot have FORGE")
			assert(p != RoomPurposeScript.Type.EXCAVATION, "FAIL: MAUSOLEUM cannot have EXCAVATION")

		# FORTRESS no debe contener CRYPT ni EXCAVATION
		var cfg_f := DungeonConfigScript.new()
		cfg_f.seed = s
		cfg_f.dungeon_archetype = DungeonArchetypeScript.Type.FORTRESS
		var res_f = pipeline.generate(cfg_f)
		var sem_f = orchestrator.generate_semantics(res_f, cfg_f)

		for r_id in sem_f.room_purposes:
			var p = sem_f.room_purposes[r_id]
			assert(p != RoomPurposeScript.Type.CRYPT, "FAIL: FORTRESS cannot have CRYPT")
			assert(p != RoomPurposeScript.Type.EXCAVATION, "FAIL: FORTRESS cannot have EXCAVATION")
			assert(p != RoomPurposeScript.Type.SHRINE, "FAIL: FORTRESS cannot have SHRINE")

		# MINE no debe contener THRONE_ROOM ni SANCTUM
		var cfg_mine := DungeonConfigScript.new()
		cfg_mine.seed = s
		cfg_mine.dungeon_archetype = DungeonArchetypeScript.Type.MINE
		var res_mine = pipeline.generate(cfg_mine)
		var sem_mine = orchestrator.generate_semantics(res_mine, cfg_mine)

		for r_id in sem_mine.room_purposes:
			var p = sem_mine.room_purposes[r_id]
			assert(p != RoomPurposeScript.Type.THRONE_ROOM, "FAIL: MINE cannot have THRONE_ROOM")
			assert(p != RoomPurposeScript.Type.SANCTUM, "FAIL: MINE cannot have SANCTUM")
			assert(p != RoomPurposeScript.Type.CRYPT, "FAIL: MINE cannot have CRYPT")

		# TEMPLE no debe contener ARMORY ni FORGE
		var cfg_t := DungeonConfigScript.new()
		cfg_t.seed = s
		cfg_t.dungeon_archetype = DungeonArchetypeScript.Type.TEMPLE
		var res_t = pipeline.generate(cfg_t)
		var sem_t = orchestrator.generate_semantics(res_t, cfg_t)

		for r_id in sem_t.room_purposes:
			var p = sem_t.room_purposes[r_id]
			assert(p != RoomPurposeScript.Type.ARMORY, "FAIL: TEMPLE cannot have ARMORY")
			assert(p != RoomPurposeScript.Type.FORGE, "FAIL: TEMPLE cannot have FORGE")

	print("  [OK] Strict archetype incompatibilities verified across multiple seeds.")
	print("[PASS] test_archetype_semantics completed successfully.")
	quit(0)
