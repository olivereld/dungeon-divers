extends SceneTree

const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_carve_result ---")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(10, 10, 10, 10), &"sanctum")
	var geom := _GeomPolicyScript.new([&"cruciform"], 8, 14, 8, 14, 64, 196)
	var ent := _EntPolicyScript.new(1, 2, [&"south", &"east"])
	var anchors: Dictionary = {
		&"altar": _AnchorDefScript.new(&"altar", true, &"center"),
		&"relic": _AnchorDefScript.new(&"relic", false, &"north_wall")
	}
	var tpl := _RoomTemplateScript.new(&"sanctum_tpl", "Sanctum", [], geom, ent, null, anchors)

	var entrance := Vector2i(14, 19) # South entrance
	var res = _ShapeCarverScript.carve(grid, room, tpl, [entrance], RandomNumberGenerator.new(), 0)

	assert(res != null, "FAIL: carve result should not be null")
	assert(res.is_success, "FAIL: carve should succeed")
	assert(res.zone_map != null, "FAIL: zone_map must exist")
	assert(res.resolved_anchors.has(&"altar"), "FAIL: altar anchor must be resolved")
	assert(res.resolved_anchors.has(&"relic"), "FAIL: relic anchor must be resolved")

	var altar_pos: Vector2i = res.resolved_anchors[&"altar"]
	assert(altar_pos == room.get_center(), "FAIL: altar should be at room center")
	assert(grid.is_walkable(altar_pos), "FAIL: altar position must be walkable")

	var relic_pos: Vector2i = res.resolved_anchors[&"relic"]
	assert(relic_pos.y <= room.rect.position.y + 2, "FAIL: relic must be near north wall, got y=%d (rect.y=%d)" % [relic_pos.y, room.rect.position.y])
	assert(grid.is_walkable(relic_pos), "FAIL: relic position must be walkable")

	print("PASS: test_room_template_carve_result passed successfully!")
	quit(0)
