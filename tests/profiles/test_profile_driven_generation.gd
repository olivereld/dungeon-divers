extends SceneTree

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_profile_driven_generation ---")

	var pipeline := DungeonPipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: Necropolis profile should be valid")

	var config := DungeonConfigScript.new()
	config.seed = 2026
	config.dungeon_archetype = &"necropolis"

	# 1. Generate full dungeon
	var result = pipeline.generate(config)
	assert(result != null and result.grid != null, "FAIL: Dungeon generation failed")
	assert(not result.rooms.is_empty(), "FAIL: Rooms should not be empty")

	# 2. Generate semantics
	var orchestrator := SemanticOrchestratorScript.new()
	var sem_res = orchestrator.generate_semantics(result, config)
	assert(sem_res != null and sem_res.gameplay_valid, "FAIL: Semantic generation failed")
	assert(not sem_res.room_purposes.is_empty(), "FAIL: Room purposes must be assigned")

	# 3. Build Presentation Contexts
	var builder := PresentationContextBuilderScript.new()
	var room_contexts = builder.build_contexts(sem_res)
	assert(room_contexts.size() == result.rooms.size(), "FAIL: Every room must have a PresentationRoomContext")

	# 4. Verify each PresentationRoomContext carries a valid ProfileRoom loaded from JSON
	for ctx in room_contexts:
		assert(ctx.room_profile != null, "FAIL: RoomContext for room %d must carry a resolved ProfileRoom" % ctx.room_id)
		assert(ctx.room_profile.id != &"", "FAIL: ProfileRoom must have valid ID")
		assert(ctx.room_profile.schema_version == 1, "FAIL: ProfileRoom must have schema_version 1")
		assert(ctx.room_profile.intent != null, "FAIL: ProfileRoom must have an intent")
		assert(ctx.room_profile.composition != null, "FAIL: ProfileRoom must have a composition")
		assert(ctx.room_profile.lighting != null, "FAIL: ProfileRoom must have lighting config")

		# Check specific purpose mappings
		if ctx.purpose == RoomPurposeScript.Type.CRYPT:
			assert(ctx.room_profile.id == &"crypt", "FAIL: CRYPT purpose must carry crypt room profile")
		elif ctx.purpose == RoomPurposeScript.Type.TOMB:
			assert(ctx.room_profile.id == &"tomb", "FAIL: TOMB purpose must carry tomb room profile")
		elif ctx.purpose == RoomPurposeScript.Type.ROYAL_TOMB:
			assert(ctx.room_profile.id == &"royal_tomb", "FAIL: ROYAL_TOMB purpose must carry royal_tomb room profile")
		elif ctx.purpose == RoomPurposeScript.Type.ENTRANCE:
			assert(ctx.room_profile.id == &"entrance", "FAIL: ENTRANCE purpose must carry entrance room profile")

	print("[PASS] test_profile_driven_generation completed successfully!")
	quit(0)
