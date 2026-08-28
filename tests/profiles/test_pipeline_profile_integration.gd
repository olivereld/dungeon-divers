extends SceneTree

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_pipeline_profile_integration ---")

	var pipeline := DungeonPipelineScript.new()

	# 1. Test load_profiles on pipeline
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: Pipeline profile loading for necropolis should be valid")
	assert(pipeline.get_profile_bundle() != null, "FAIL: Pipeline should store loaded profile bundle")

	# 2. Test ProfileArchetype properties
	var bundle = pipeline.get_profile_bundle()
	var arch_prof = bundle.archetype
	assert(arch_prof.id == &"necropolis", "FAIL: Converted archetype ID mismatch")
	assert(arch_prof.purpose_weights.has("crypt"), "FAIL: Missing crypt in purpose_weights")
	assert(arch_prof.purpose_weights["crypt"] == 4.0, "FAIL: Crypt weight mismatch")
	assert(arch_prof.get_allowed_purposes_for_gameplay(&"BOSS").has(&"royal_tomb"), "FAIL: Boss role missing royal_tomb")

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
