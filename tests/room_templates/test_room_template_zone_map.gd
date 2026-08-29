extends SceneTree

const _ZoneMapScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_zone_map ---")
	var rect := Rect2i(10, 10, 8, 8)
	var zm = _ZoneMapScript.new(rect)
	
	assert(zm.room_rect == rect, "FAIL: room_rect mismatch")
	zm.set_zone(Vector2i(12, 12), &"focal")
	zm.set_zone(Vector2i(10, 10), &"entrance_clearance")
	
	assert(zm.get_zone(Vector2i(12, 12)) == &"focal", "FAIL: focal zone mismatch")
	assert(zm.get_zone(Vector2i(10, 10)) == &"entrance_clearance", "FAIL: entrance zone mismatch")
	assert(zm.get_zone(Vector2i(11, 11)) == &"unassigned", "FAIL: default zone should be unassigned")
	assert(zm.get_cells_in_zone(&"focal").size() == 1, "FAIL: cells count mismatch")
	assert(zm.has_zone(&"focal") == true, "FAIL: has_zone for focal should be true")
	assert(zm.has_zone(&"circulation") == false, "FAIL: has_zone for circulation should be false")
	
	print("PASS: test_room_template_zone_map passed successfully!")
	quit(0)
