extends SceneTree

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const DungeonArchetypeProfileScript = preload("res://src/dungeon_generator/config/dungeon_archetype_profile.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_pipeline_profile_integration ---")

	var pipeline := DungeonPipelineScript.new()

	# 1. Test load_profiles on pipeline
	var val_res = pipeline.load_profiles("mausoleum")
	assert(val_res.is_valid, "FAIL: Pipeline profile loading for mausoleum should be valid")
	assert(pipeline.get_profile_bundle() != null, "FAIL: Pipeline should store loaded profile bundle")

	# 2. Test DungeonArchetypeProfile.from_profile conversion
	var bundle = pipeline.get_profile_bundle()
	var arch_prof = DungeonArchetypeProfileScript.from_profile(bundle.archetype)
	assert(arch_prof.archetype == DungeonArchetypeScript.Type.MAUSOLEUM, "FAIL: Converted archetype type mismatch")
	assert(arch_prof.purpose_weights.has(int(RoomPurposeScript.Type.CRYPT)), "FAIL: Missing CRYPT in purpose_weights")
	assert(arch_prof.purpose_weights[int(RoomPurposeScript.Type.CRYPT)] == 4.0, "FAIL: Crypt weight mismatch")
	assert(arch_prof.get_allowed_purposes_for_gameplay("BOSS").has(int(RoomPurposeScript.Type.ROYAL_TOMB)), "FAIL: Boss role missing ROYAL_TOMB")

	# 3. Test generate() execution with loaded pipeline
	var config := DungeonConfigScript.new()
	config.seed = 1337
	config.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	var result = pipeline.generate(config)
	assert(result != null, "FAIL: Pipeline generation result should not be null")
	assert(result.grid != null, "FAIL: Generated result grid should not be null")
	assert(not result.rooms.is_empty(), "FAIL: Generated rooms should not be empty")

	print("[PASS] test_pipeline_profile_integration completed successfully!")
	quit(0)
