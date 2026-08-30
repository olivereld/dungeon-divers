extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_sacristy_v1_resolution ---")
	var pipeline = _DungeonPipelineScript.new()
	var val_res = pipeline.load_profiles("necropolis")
	assert(val_res.is_valid, "FAIL: necropolis bundle must be valid")

	var bundle = pipeline.get_profile_bundle()
	assert(bundle.template_registry.has_template(&"sacristy_v1"), "FAIL: sacristy_v1 must be in template registry")

	var sacristy_profile = bundle.get_room(&"sacristy")
	var boss_profile = bundle.get_room(&"royal_tomb")
	var crypt_profile = bundle.get_room(&"crypt")

	var resolver := RoomTemplateResolver.new(bundle.template_registry)
	var matcher := RoomTemplateMatcher.new(bundle.template_registry)
	var tpl = bundle.template_registry.get_template(&"sacristy_v1")

	var room_sacristy := RoomData.new(1, Rect2i(5, 5, 12, 12), &"sacristy")
	var room_boss := RoomData.new(2, Rect2i(5, 5, 12, 12), &"boss")
	var room_crypt := RoomData.new(3, Rect2i(5, 5, 12, 12), &"combat")

	# 1. Sacristy must match sacristy_v1
	assert(matcher.is_compatible(tpl, room_sacristy, sacristy_profile, []) == true, "FAIL: sacristy_v1 must match sacristy")
	var chosen_sacristy = resolver.resolve_template(room_sacristy, sacristy_profile, [], 42)
	assert(chosen_sacristy != null and chosen_sacristy.id == &"sacristy_v1", "FAIL: sacristy should resolve sacristy_v1")

	# 2. Boss and Crypt must NOT match sacristy_v1
	assert(matcher.is_compatible(tpl, room_boss, boss_profile, []) == false, "FAIL: sacristy_v1 must NOT match royal_tomb / boss")
	assert(matcher.is_compatible(tpl, room_crypt, crypt_profile, []) == false, "FAIL: sacristy_v1 must NOT match crypt")

	print("PASS: test_sacristy_v1_resolution passed successfully!")
	quit(0)
