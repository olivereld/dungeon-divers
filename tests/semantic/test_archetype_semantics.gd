extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_archetype_semantics ---")
	print("==================================================================")

	var loader := ProfileLoaderScript.new()

	# Test A: Validación de integridad de los perfiles disponibles
	var ids = loader.list_available_archetypes()
	assert(ids.size() > 0, "FAIL: Archetype catalog should have registered archetypes")
	for arch_id in ids:
		var bundle = loader.load_full_archetype_bundle(str(arch_id))
		assert(bundle != null and bundle.archetype != null, "FAIL: Bundle should load valid archetype")
		assert(not bundle.archetype.purpose_weights.is_empty(), "FAIL: Profile weights cannot be empty")

	# Test B: Incompatibilidades estrictas en generación completa con necropolis
	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()

	var arch_seeds = [1111, 2222, 3333, 4444]
	for s in arch_seeds:
		# NECROPOLIS no debe contener ARMORY ni FORGE
		var cfg_m := DungeonConfigScript.new()
		cfg_m.seed = s
		cfg_m.archetype_id = &"necropolis"
		var res_m = pipeline.generate(cfg_m)
		var sem_m = orchestrator.generate_semantics(res_m, cfg_m)

		for r_id in sem_m.room_purposes:
			var p = sem_m.room_purposes[r_id]
			assert(p != &"armory", "FAIL: NECROPOLIS cannot have ARMORY")
			assert(p != &"forge", "FAIL: NECROPOLIS cannot have FORGE")
			assert(p != &"excavation", "FAIL: NECROPOLIS cannot have EXCAVATION")

	print("  [OK] Strict archetype incompatibilities verified across multiple seeds.")
	print("[PASS] test_archetype_semantics completed successfully.")
	quit(0)
