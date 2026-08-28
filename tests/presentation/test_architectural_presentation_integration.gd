extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_architectural_presentation_integration ---")
	print("==================================================================")

	var archetypes = [
		&"generic",
		&"necropolis",
		&"fortress",
		&"temple",
		&"mine"
	]

	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()
	var pres_builder := DungeonPresentationBuilderScript.new()

	for arch in archetypes:
		var cfg := DungeonConfigScript.new()
		cfg.seed = 98765 + int(arch) * 100
		cfg.use_fixed_seed = true
		cfg.dungeon_archetype = arch

		var res = pipeline.generate(cfg, 5, true)
		assert(res != null, "FAIL: DungeonResult must not be null")
		var sem_res = orchestrator.generate_semantics(res, cfg)
		assert(sem_res != null, "FAIL: DungeonSemanticResult must not be null")

		var parent_node := Node3D.new()
		root.add_child(parent_node)

		var biome := BiomeProfileScript.new()
		var pres_res = pres_builder.build_presentation(sem_res, parent_node, biome, cfg)

		assert(pres_res != null, "FAIL: PresentationResult must not be null")
		assert(not pres_res.has_blocking_errors(), "FAIL: Presentation build must not have blocking errors")
		assert(parent_node.get_child_count() > 0, "FAIL: 3D presentation must spawn children in parent")

		parent_node.queue_free()

	print("  [OK] 3D Presentation built successfully across all 5 archetypes.")
	print("[PASS] test_architectural_presentation_integration completed successfully.")
	quit(0)
