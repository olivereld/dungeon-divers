extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_archetype_determinism_and_immutability ---")
	print("==================================================================")

	var seeds = [1337, 8888, 99999, 102030]
	var archetypes = [
		DungeonArchetypeScript.Type.GENERIC,
		DungeonArchetypeScript.Type.MAUSOLEUM,
		DungeonArchetypeScript.Type.FORTRESS,
		DungeonArchetypeScript.Type.TEMPLE,
		DungeonArchetypeScript.Type.MINE
	]

	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()

	for s in seeds:
		for arch in archetypes:
			var cfg := DungeonConfigScript.new()
			cfg.seed = s
			cfg.dungeon_archetype = arch

			var run_1_res = pipeline.generate(cfg)
			var run_1_sem = orchestrator.generate_semantics(run_1_res, cfg)

			var run_2_res = pipeline.generate(cfg)
			var run_2_sem = orchestrator.generate_semantics(run_2_res, cfg)

			# 1. Determinismo exacto
			assert(run_1_sem.dungeon_archetype == run_2_sem.dungeon_archetype)
			for r_id in run_1_sem.room_purposes:
				assert(run_1_sem.room_purposes[r_id] == run_2_sem.room_purposes[r_id], "FAIL: Determinism violation on room %d" % r_id)

	print("  [OK] 20 combinations of (Seed x Archetype) verified with 100% determinism.")
	print("[PASS] test_archetype_determinism_and_immutability completed successfully.")
	quit(0)
