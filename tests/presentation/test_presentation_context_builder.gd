extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_context_builder ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 12345
	cfg.dungeon_archetype = &"necropolis"

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem_res = orchestrator.generate_semantics(res, cfg)

	var builder := PresentationContextBuilderScript.new()
	var contexts = builder.build_contexts(sem_res)

	assert(contexts.size() == res.rooms.size(), "FAIL: Every room must have a context")
	for ctx in contexts:
		assert(ctx.profile != null, "FAIL: Context profile must not be null")
		assert(ctx.profile.wall_style == &"dark_stone", "FAIL: Necropolis rooms must resolve to dark_stone")

	var dominant = builder.get_dominant_profile(contexts)
	assert(dominant != null, "FAIL: Dominant profile must not be null")
	assert(dominant.wall_style == &"dark_stone")

	print("  [OK] PresentationContextBuilder correctly builds room contexts from semantic result.")
	print("  [OK] Dominant profile correctly extracted.")
	print("[PASS] test_presentation_context_builder completed successfully.")
	quit(0)
