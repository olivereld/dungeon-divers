extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_crypt_variants_resolution ---")
	var pipeline = _DungeonPipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: necropolis bundle must be valid")

	var bundle = pipeline.get_profile_bundle()
	for v in ["crypt_v1", "crypt_v2", "crypt_v3", "crypt_v4", "crypt_v5", "crypt_v6", "crypt_v7", "crypt_v8", "crypt_v9", "crypt_v10"]:
		assert(bundle.template_registry.has_template(StringName(v)), "FAIL: %s must be in template registry" % v)

	var crypt_profile = bundle.get_room(&"crypt")
	assert(crypt_profile != null, "FAIL: crypt profile must exist")
	assert(crypt_profile.template_constraints.is_template_preferred(&"crypt_v1"), "FAIL: crypt_v1 must be preferred in crypt.json")

	var sacristy_profile = bundle.get_room(&"sacristy")
	assert(sacristy_profile.template_constraints.allowed_templates.is_empty(), "FAIL: sacristy templates must be empty")

	var resolver := RoomTemplateResolver.new(bundle.template_registry)
	var matcher := RoomTemplateMatcher.new(bundle.template_registry)

	var room_crypt := RoomData.new(1, Rect2i(5, 5, 12, 12), &"combat")
	var room_sacristy := RoomData.new(2, Rect2i(5, 5, 12, 12), &"treasure")
	var room_boss := RoomData.new(3, Rect2i(5, 5, 12, 12), &"boss")

	# 1. Crypt room matches crypt templates
	var chosen_crypt = resolver.resolve_template(room_crypt, crypt_profile, [], 100)
	assert(chosen_crypt != null and chosen_crypt.id in [&"crypt_v1", &"crypt_v2", &"crypt_v3", &"crypt_v4"], "FAIL: crypt should resolve a crypt template")
	print("Crypt resolved template: ", chosen_crypt.id)

	# 2. Sacristy room does not resolve crypt templates
	var chosen_sacristy = resolver.resolve_template(room_sacristy, sacristy_profile, [], 100)
	assert(chosen_sacristy == null or chosen_sacristy.id == &"procedural_fallback", "FAIL: sacristy must not resolve crypt templates")

	print("PASS: test_crypt_variants_resolution passed successfully!")
	quit(0)
