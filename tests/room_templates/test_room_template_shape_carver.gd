extends SceneTree

const _CarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_shape_carver ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	# Test 1: Octagonal Chamber with Entrance
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(5, 5, 12, 12), &"chamber")
	var geom_oct := _GeometryPolicyScript.new([&"octagonal", &"octagonal_chamber"], 6, 20, 6, 20, 36, 400, 0.5, 2.0)
	var tpl_oct := _RoomTemplateScript.new(&"octagonal_test", "Octagon", [], geom_oct)
	var entrances: Array[Vector2i] = [Vector2i(10, 5)]
	
	var zm_oct = _CarverScript.carve_room_shape(grid, room, tpl_oct, entrances, rng)
	assert(zm_oct != null, "FAIL: zone_map should not be null")
	assert(grid.get_cell(Vector2i(10, 5)) == CellGrid.CellType.FLOOR, "FAIL: entrance must be floor")
	assert(grid.get_cell(room.get_center()) == CellGrid.CellType.FLOOR, "FAIL: center must be floor")
	_assert_walkability(grid, room, 0.70)
	
	# Test 2: Open Rectangle
	var grid2 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var geom_rect := _GeometryPolicyScript.new([&"rectangle", &"open_rectangle"], 5, 20, 5, 20, 25, 400, 0.5, 2.0)
	var tpl_rect := _RoomTemplateScript.new(&"rect_test", "Rectangle", [], geom_rect)
	var zm_rect = _CarverScript.carve_room_shape(grid2, room, tpl_rect, entrances, rng)
	assert(zm_rect != null, "FAIL: zone_map for rect should not be null")
	_assert_walkability(grid2, room, 0.95)
	
	# Test 3: Cruciform Sanctuary
	var grid3 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var geom_cross := _GeometryPolicyScript.new([&"cruciform", &"cruciform_sanctuary"], 7, 20, 7, 20, 49, 400, 0.5, 2.0)
	var tpl_cross := _RoomTemplateScript.new(&"cross_test", "Cross", [], geom_cross)
	var zm_cross = _CarverScript.carve_room_shape(grid3, room, tpl_cross, entrances, rng)
	assert(zm_cross != null, "FAIL: zone_map for cross should not be null")
	_assert_walkability(grid3, room, 0.70)
	
	# Test 4: Pillared Hall
	var grid4 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var geom_pil := _GeometryPolicyScript.new([&"pillared", &"pillared_hall"], 8, 20, 8, 20, 64, 400, 0.5, 2.0)
	var tpl_pil := _RoomTemplateScript.new(&"pil_test", "Pillars", [], geom_pil)
	var zm_pil = _CarverScript.carve_room_shape(grid4, room, tpl_pil, entrances, rng)
	assert(zm_pil != null, "FAIL: zone_map for pillars should not be null")
	_assert_walkability(grid4, room, 0.75)
	
	# Test 5: Chapel (Nave + Focal Apse)
	var grid5 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var geom_chapel := _GeometryPolicyScript.new([&"chapel"], 7, 20, 7, 20, 49, 400, 0.5, 2.0)
	var tpl_chapel := _RoomTemplateScript.new(&"chapel_test", "Chapel", [], geom_chapel)
	var zm_chapel = _CarverScript.carve_room_shape(grid5, room, tpl_chapel, entrances, rng)
	assert(zm_chapel != null, "FAIL: zone_map for chapel should not be null")
	assert(zm_chapel.has_zone(&"focal"), "FAIL: chapel must have focal zone")
	_assert_walkability(grid5, room, 0.70)
	
	print("PASS: test_room_template_shape_carver passed successfully!")
	quit(0)

func _assert_walkability(grid: CellGrid, room: RoomData, min_ratio: float) -> void:
	var walkable := 0
	var total: int = room.rect.size.x * room.rect.size.y
	for y in range(room.rect.position.y, room.rect.end.y):
		for x in range(room.rect.position.x, room.rect.end.x):
			if grid.is_walkable(Vector2i(x, y)):
				walkable += 1
	var ratio: float = float(walkable) / float(total)
	assert(ratio >= min_ratio, "FAIL: walkability ratio (%.2f) < min_ratio (%.2f)" % [ratio, min_ratio])
