extends SceneTree

const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_orientation ---")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(10, 10, 10, 12), &"chapel")
	var geom := _GeomPolicyScript.new([&"chapel"], 8, 14, 8, 14, 64, 196)
	var ent := _EntPolicyScript.new(1, 2, [&"south", &"north", &"east", &"west"])
	var anchors: Dictionary = {
		&"apse_altar": _AnchorDefScript.new(&"apse_altar", true, &"north_wall")
	}
	var tpl := _RoomTemplateScript.new(&"chapel_tpl", "Chapel", [], geom, ent, null, anchors)

	# When entrance is at South, orientation 0 (NORTH) faces the apse to North
	var entrance_south := Vector2i(14, 21)
	var res_north = _ShapeCarverScript.carve(grid, room, tpl, [entrance_south], RandomNumberGenerator.new(), 0)
	var altar_north = res_north.resolved_anchors[&"apse_altar"]
	assert(altar_north.y <= room.rect.position.y + 2, "FAIL: with north orientation, apse should be near north wall, got y=%d" % altar_north.y)

	# When entrance is at North, orientation 2 (SOUTH) faces the apse to South
	var entrance_north := Vector2i(14, 10)
	var res_south = _ShapeCarverScript.carve(grid, room, tpl, [entrance_north], RandomNumberGenerator.new(), 2)
	var altar_south = res_south.resolved_anchors[&"apse_altar"]
	assert(altar_south.y >= room.rect.end.y - 3, "FAIL: with south orientation, apse should be near south wall, got y=%d" % altar_south.y)

	# Automatic orientation calculation from primary entrance side
	var auto_north = _ShapeCarverScript.determine_orientation_from_entrances(room.rect, [entrance_south])
	assert(auto_north == 0, "FAIL: south entrance should yield north orientation (0), got %d" % auto_north)

	var auto_south = _ShapeCarverScript.determine_orientation_from_entrances(room.rect, [entrance_north])
	assert(auto_south == 2, "FAIL: north entrance should yield south orientation (2), got %d" % auto_south)

	print("PASS: test_room_template_orientation passed successfully!")
	quit(0)
