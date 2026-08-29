extends SceneTree

const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_deterministic_shape_choice ---")
	var grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(10, 10, 10, 10), &"explore")
	var geom := _GeomPolicyScript.new([&"octagonal", &"rectangle"], 8, 14, 8, 14, 64, 196)
	var ent := _EntPolicyScript.new(1, 2)
	var tpl := _RoomTemplateScript.new(&"multi_shape_tpl", "MultiShape", [], geom, ent)

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 100
	var res1 = _ShapeCarverScript.carve(grid, room, tpl, [Vector2i(14, 19)], rng1, 0)
	assert(res1 != null and res1.is_success, "FAIL: res1 should succeed")

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 101
	var res2 = _ShapeCarverScript.carve(grid, room, tpl, [Vector2i(14, 19)], rng2, 0)
	assert(res2 != null and res2.is_success, "FAIL: res2 should succeed")

	# Verify repeatability with identical seeds
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 100
	var res3 = _ShapeCarverScript.carve(grid, room, tpl, [Vector2i(14, 19)], rng3, 0)
	assert(res1.diagnostics["shape_family"] == res3.diagnostics["shape_family"], "FAIL: identical seeds must produce identical shapes")

	print("PASS: test_deterministic_shape_choice passed successfully!")
	quit(0)
