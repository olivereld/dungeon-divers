extends SceneTree

const _MatcherScript = preload("res://src/dungeon_generator/core/room_templates/matcher/room_template_matcher.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_matcher ---")
	var matcher := _MatcherScript.new(null)

	var geom_small := _GeomPolicyScript.new([&"rectangle"], 6, 8, 6, 8, 36, 64)
	var ent_single := _EntPolicyScript.new(1, 2, [&"north", &"south", &"west"])
	var tpl_small := _RoomTemplateScript.new(&"small_tpl", "Small", [&"small"], geom_small, ent_single)
	tpl_small.allowed_purposes = [&"sacristy"]

	var room_ok := RoomData.new(1, Rect2i(0, 0, 7, 7), &"sacristy")
	var room_too_big := RoomData.new(2, Rect2i(0, 0, 12, 12), &"sacristy")
	var room_wrong_purpose := RoomData.new(3, Rect2i(0, 0, 7, 7), &"armory")

	# Entrance on West (x=0, y=3)
	var west_entrance := Vector2i(0, 3)
	# Entrance on East (forbidden)
	var east_entrance := Vector2i(6, 3)

	assert(matcher.is_compatible(tpl_small, room_ok, null, [west_entrance]), "FAIL: should be compatible")
	assert(not matcher.is_compatible(tpl_small, room_too_big, null, []), "FAIL: should reject oversized room")
	assert(not matcher.is_compatible(tpl_small, room_wrong_purpose, null, []), "FAIL: should reject incompatible purpose")
	assert(not matcher.is_compatible(tpl_small, room_ok, null, [east_entrance]), "FAIL: should reject forbidden entrance side")

	var filtered = matcher.filter_compatible_templates([tpl_small], room_ok, null, [west_entrance])
	assert(filtered.size() == 1, "FAIL: filter should return 1 compatible template")

	print("PASS: test_room_template_matcher passed successfully!")
	quit(0)
