extends SceneTree

const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_shape_carver_invariants ---")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(5, 5, 10, 10), &"sanctum")
	var geom := _GeomPolicyScript.new([&"octagonal"], 8, 12, 8, 12, 64, 144)
	var ent := _EntPolicyScript.new(1, 2, [&"north", &"south", &"west"])
	var tpl := _RoomTemplateScript.new(&"octagonal_tpl", "Octagonal", [], geom, ent)

	var entrance_a := Vector2i(5, 7) # West entrance
	var entrance_b := Vector2i(9, 14) # South entrance
	var zm = _ShapeCarverScript.carve_room_shape(grid, room, tpl, [entrance_a, entrance_b], RandomNumberGenerator.new())

	assert(zm != null, "FAIL: zone map should not be null")
	assert(grid.is_walkable(entrance_a), "FAIL: entrance_a must be walkable")
	assert(grid.is_walkable(entrance_b), "FAIL: entrance_b must be walkable")
	assert(grid.is_walkable(room.get_center()), "FAIL: room center must be walkable")

	# Check walkability ratio >= 0.70
	var walkable := 0
	for y in range(room.rect.position.y, room.rect.end.y):
		for x in range(room.rect.position.x, room.rect.end.x):
			if grid.is_walkable(Vector2i(x, y)):
				walkable += 1
	var ratio := float(walkable) / float(room.rect.size.x * room.rect.size.y)
	assert(ratio >= 0.70, "FAIL: walkability ratio %.2f is below 70%%" % ratio)

	# Verify BFS connectivity from entrance_a to entrance_b and center
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [entrance_a]
	visited[entrance_a] = true
	while not queue.is_empty():
		var curr = queue.pop_front()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = curr + offset
			if room.rect.has_point(n) and grid.is_walkable(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)

	assert(visited.has(entrance_b), "FAIL: entrance_b must be reachable from entrance_a via walkable floor")
	assert(visited.has(room.get_center()), "FAIL: room center must be reachable from entrance_a via walkable floor")

	print("PASS: test_room_template_shape_carver_invariants passed successfully!")
	quit(0)
