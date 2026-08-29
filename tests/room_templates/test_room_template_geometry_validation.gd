extends SceneTree

const _ValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validator.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_geometry_validation ---")
	var validator := _ValidatorScript.new()

	# Pillared hall requires at least 8x8 space for pillars
	var geom_pillared := _GeomPolicyScript.new([&"pillared_hall"], 6, 16, 6, 16, 36, 256)
	var ent := _EntPolicyScript.new(1, 2)
	var tpl_pillared := _RoomTemplateScript.new(&"pillared_tpl", "Pillared", [], geom_pillared, ent)

	var rect_small := Rect2i(0, 0, 6, 6) # Too small for pillared hall layout
	var rect_ok := Rect2i(0, 0, 10, 10)

	var res_small = validator.validate_shape_feasibility(tpl_pillared, rect_small)
	assert(not res_small.is_valid, "FAIL: pillared hall in 6x6 room should fail shape feasibility")

	var res_ok = validator.validate_shape_feasibility(tpl_pillared, rect_ok)
	assert(res_ok.is_valid, "FAIL: pillared hall in 10x10 room should be valid")

	# Cruciform requires at least 7x7
	var geom_cruciform := _GeomPolicyScript.new([&"cruciform"], 5, 16, 5, 16, 25, 256)
	var tpl_cruciform := _RoomTemplateScript.new(&"cruciform_tpl", "Cruciform", [], geom_cruciform, ent)
	var res_cruc_small = validator.validate_shape_feasibility(tpl_cruciform, Rect2i(0, 0, 5, 5))
	assert(not res_cruc_small.is_valid, "FAIL: cruciform in 5x5 room should fail shape feasibility")

	var res_cruc_ok = validator.validate_shape_feasibility(tpl_cruciform, Rect2i(0, 0, 9, 9))
	assert(res_cruc_ok.is_valid, "FAIL: cruciform in 9x9 room should be valid")

	print("PASS: test_room_template_geometry_validation passed successfully!")
	quit(0)
