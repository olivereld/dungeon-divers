extends SceneTree

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")

func _init() -> void:
	print("--- Running test_room_template_resolver_diagnostics ---")
	var pipeline = _PipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: necropolis bundle must be valid")

	var bundle = pipeline.get_profile_bundle()
	var resolver := _RoomTemplateResolverScript.new(bundle.template_registry)

	var room_crypt := RoomData.new(1, Rect2i(5, 5, 12, 12), &"combat")
	var crypt_profile = bundle.get_room(&"crypt")

	var diag = resolver.resolve_with_diagnostics(room_crypt, crypt_profile, [], 100001)
	assert(diag != null, "FAIL: diagnostics must not be null")
	assert(diag.has("resolved_template_id"), "FAIL: diag must have resolved_template_id")
	assert(diag.has("candidate_templates"), "FAIL: diag must have candidate_templates")
	assert(diag.has("compatible_templates"), "FAIL: diag must have compatible_templates")
	assert(diag.has("rejected_templates"), "FAIL: diag must have rejected_templates")
	assert(not diag["is_fallback"], "FAIL: 12x12 crypt should not fallback")
	assert(diag["resolved_template_id"] in [&"crypt_v1", &"crypt_v2", &"crypt_v3", &"crypt_v4", &"crypt_v5", &"crypt_v6", &"crypt_v7", &"crypt_v8", &"crypt_v9", &"crypt_v10"], "FAIL: expected crypt template")

	# Small room that cannot fit crypt_v2 (12x12 min 10x10) if tested against 4x4
	var room_tiny := RoomData.new(2, Rect2i(5, 5, 4, 4), &"combat")
	var diag_tiny = resolver.resolve_with_diagnostics(room_tiny, crypt_profile, [], 100001)
	assert(diag_tiny["is_fallback"], "FAIL: 4x4 room must fallback")
	assert(not diag_tiny["rejected_templates"].is_empty(), "FAIL: rejected_templates must document causes")

	print("PASS: test_room_template_resolver_diagnostics passed!")
	quit(0)
