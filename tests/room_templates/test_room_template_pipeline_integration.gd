extends SceneTree

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_pipeline_integration ---")
	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_bundle("res://resources/dungeon_profiles/archetypes/necropolis.json")
	assert(bundle != null, "FAIL: bundle should load successfully")
	assert(bundle.template_registry != null, "FAIL: bundle must have template_registry")

	var pipeline := _PipelineScript.new()
	var config := DungeonConfig.new()
	config.grid_width = 60
	config.grid_height = 60
	config.min_target_rooms = 6
	config.max_target_rooms = 10
	config.mission_depth = 5
	config.algorithm = "Template"

	var result = pipeline.generate(config, 424242, bundle)
	assert(result != null, "FAIL: result should not be null")
	assert(result.grid != null, "FAIL: grid must not be null")
	assert(result.validation != null and result.validation.hard_valid, "FAIL: dungeon must satisfy quality gate hard constraints")
	assert(not result.rooms.is_empty(), "FAIL: rooms must not be empty")

	# Verify each room was carved with valid walkability and internal connectivity
	for room in result.rooms:
		var walkable := 0
		var total: int = room.rect.size.x * room.rect.size.y
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				if result.grid.is_walkable(Vector2i(x, y)):
					walkable += 1
		var ratio: float = float(walkable) / float(total)
		assert(ratio >= 0.70, "FAIL: room %d walkability ratio %.2f is below 70%%" % [room.id, ratio])

	print("PASS: test_room_template_pipeline_integration passed successfully!")
	quit(0)
