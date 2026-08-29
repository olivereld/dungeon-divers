extends SceneTree

const _LabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_lab_state ---")
	var state := _LabStateScript.new()

	# 1. Test tile painting and cell retrieval
	state.set_cell(Vector2i(2, 2), 1)
	state.set_cell(Vector2i(3, 2), 1)
	state.set_cell(Vector2i(4, 2), 1)
	assert(state.get_cell(Vector2i(2, 2)) == 1, "FAIL: cell (2,2) should be 1")
	assert(state.get_cell(Vector2i(0, 0)) == 0, "FAIL: unpainted cell should be 0")
	assert(state.get_painted_cell_count() == 3, "FAIL: expected 3 painted cells")

	# 2. Test auto-calculate geometry from painted tiles
	state.set_cell(Vector2i(2, 5), 1)
	state.set_cell(Vector2i(4, 5), 1)
	var geom_info = state.auto_calculate_geometry()
	assert(geom_info["min_x"] == 2 and geom_info["max_x"] == 4, "FAIL: X bounds mismatch")
	assert(geom_info["min_y"] == 2 and geom_info["max_y"] == 5, "FAIL: Y bounds mismatch")
	assert(geom_info["width"] == 3, "FAIL: width should be 3, got %d" % geom_info["width"])
	assert(geom_info["height"] == 4, "FAIL: height should be 4, got %d" % geom_info["height"])
	assert(geom_info["area"] == 5, "FAIL: area should be 5 painted cells, got %d" % geom_info["area"])

	# 3. Test anchor placement & retrieval
	state.set_anchor(&"altar", Vector2i(3, 3))
	assert(state.has_anchor(&"altar"), "FAIL: altar anchor should exist")
	assert(state.get_anchor(&"altar") == Vector2i(3, 3), "FAIL: altar coordinate mismatch")

	# 4. Test entrance placement & retrieval
	state.add_entrance(Vector2i(3, 2))
	assert(state.get_entrances().has(Vector2i(3, 2)), "FAIL: entrance (3,2) should be registered")

	# 5. Test load from existing RoomTemplate
	var geom := _GeomPolicyScript.new([&"octagonal"], 6, 12, 6, 12, 36, 144)
	var ent := _EntPolicyScript.new(1, 2, [&"south"])
	var anchors: Dictionary = {
		&"relic": _AnchorDefScript.new(&"relic", true, &"center")
	}
	var tpl := _RoomTemplateScript.new(&"test_sanctum", "Test Sanctum", [&"ceremonial"], geom, ent, null, anchors)
	state.load_from_template(tpl)
	assert(state.template_id == &"test_sanctum", "FAIL: template_id mismatch")
	assert(state.display_name == "Test Sanctum", "FAIL: display_name mismatch")
	assert(state.has_anchor(&"relic"), "FAIL: loaded template should have relic anchor")

	# 6. Test build RoomTemplate from State
	state.template_id = &"built_template"
	state.display_name = "Built Template"
	var built_tpl = state.build_template_from_state()
	assert(built_tpl != null, "FAIL: built template should not be null")
	assert(built_tpl.id == &"built_template", "FAIL: built template id mismatch")
	assert(built_tpl.display_name == "Built Template", "FAIL: built display_name mismatch")

	print("PASS: test_room_template_lab_state passed successfully!")
	quit(0)
