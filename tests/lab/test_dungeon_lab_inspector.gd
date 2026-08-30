extends SceneTree

const _InspectorScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd")
const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_inspector ---")
	var pipeline = _PipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: necropolis bundle must be valid")

	var bundle = pipeline.get_profile_bundle()
	var inspector = _InspectorScript.new()

	var room_crypt := RoomData.new(1, Rect2i(5, 5, 12, 12), &"combat")
	var diag = inspector.inspect_room(room_crypt, bundle, 100001)

	assert(diag != null, "FAIL: inspect_room must return a dictionary")
	assert(diag["room_id"] == 1, "FAIL: room_id mismatch")
	assert(diag["purpose"] == &"combat", "FAIL: purpose mismatch")
	assert(diag["profile_id"] in [&"crypt", &"catacomb"], "FAIL: expected mapped profile")
	assert(diag.has("candidate_templates"), "FAIL: diag must list candidates")
	assert(diag.has("compatible_templates"), "FAIL: diag must list compatible")
	assert(diag.has("rejected_templates"), "FAIL: diag must list rejection reasons")

	print("PASS: test_dungeon_lab_inspector passed!")
	quit(0)
