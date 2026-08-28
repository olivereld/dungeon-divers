extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_profile_driven_generation ---")
	print("==================================================================")

	var loader := ProfileLoaderScript.new()
	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()
	var context_builder := PresentationContextBuilderScript.new()

	var available_archetypes = loader.list_available_archetypes()
	assert(not available_archetypes.is_empty(), "FAIL: ArchetypeCatalog must find archetypes")

	# Ejecutar el pipeline completo para cada arquetipo descubierto
	for arch_id in available_archetypes:
		var config := DungeonConfigScript.new()
		config.seed = 424242
		config.archetype_id = arch_id

		var dungeon_res = pipeline.generate(config)
		assert(dungeon_res != null and dungeon_res.grid != null, "FAIL: Pipeline failed for %s" % str(arch_id))

		var semantic_res = orchestrator.generate_semantics(dungeon_res, config)
		assert(semantic_res != null and semantic_res.gameplay_valid, "FAIL: Semantic failed for %s" % str(arch_id))
		assert(semantic_res.archetype_id == arch_id, "FAIL: Semantic archetype_id mismatch")

		var room_contexts = context_builder.build_contexts(semantic_res)
		assert(room_contexts.size() == dungeon_res.rooms.size(), "FAIL: Must build context for every room")

		for ctx in room_contexts:
			assert(ctx.room_profile != null, "FAIL: RoomContext for room %d must carry a resolved ProfileRoom" % ctx.room_id)
			assert(ctx.room_profile.id != &"", "FAIL: ProfileRoom must have valid ID")
			assert(ctx.room_profile.schema_version == 1, "FAIL: ProfileRoom must have schema_version 1")
			assert(ctx.room_profile.intent != null, "FAIL: ProfileRoom must have an intent")
			assert(ctx.room_profile.composition != null, "FAIL: ProfileRoom must have a composition")
			assert(ctx.room_profile.lighting != null, "FAIL: ProfileRoom must have lighting config")

		print("  [OK] Profile-driven pipeline end-to-end validated for archetype: %s" % str(arch_id))

	print("[PASS] test_profile_driven_generation completed successfully!")
	quit(0)
