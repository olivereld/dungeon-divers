extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_architectural_dimension_decoupling ---")
	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_bundle("res://resources/dungeon_profiles/archetypes/necropolis.json")
	assert(bundle != null, "FAIL: bundle must load")

	var pipeline := _PipelineScript.new()
	var config := DungeonConfig.new()
	config.algorithm = "Template"
	config.min_target_rooms = 6
	config.max_target_rooms = 8
	config.grid_width = 50
	config.grid_height = 50
	config.mission_depth = 5

	var result = pipeline.generate(config, 998877, bundle)
	assert(result != null, "FAIL: result must not be null")
	assert(result.validation != null and result.validation.hard_valid, "FAIL: dungeon generation in Template mode must be hard_valid")
	assert(not result.rooms.is_empty(), "FAIL: rooms must not be empty")

	for room in result.rooms:
		assert("zone_map" in room.custom_data, "FAIL: room %d missing zone_map" % room.id)
		assert("resolved_template_id" in room.custom_data, "FAIL: room %d missing resolved_template_id" % room.id)
		var tid: StringName = room.custom_data["resolved_template_id"]
		assert(tid != &"", "FAIL: room %d template_id should not be empty" % room.id)
		print("  - Room %d (%s) -> Template: %s" % [room.id, room.room_type, str(tid)])

	print("PASS: test_architectural_dimension_decoupling passed successfully!")
	quit(0)
