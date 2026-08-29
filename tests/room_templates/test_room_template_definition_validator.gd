extends SceneTree

const _DefValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd")
const _LoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_definition_validator ---")
	var validator := _DefValidatorScript.new()

	var valid_dict: Dictionary = {
		"id": "valid_sanctum",
		"display_name": "Valid Sanctum",
		"geometry": {
			"shape": { "allowed": ["rectangle", "octagonal"] },
			"width": { "min": 8, "max": 16 },
			"depth": { "min": 8, "max": 16 },
			"area": { "min": 64, "max": 256 }
		},
		"entrances": {
			"min": 1, "max": 3,
			"allowed_sides": ["south", "east", "west"]
		}
	}

	var res_valid = validator.validate_definition(valid_dict)
	assert(res_valid != null, "FAIL: result should not be null")
	assert(res_valid.is_valid, "FAIL: valid template definition should pass validation: %s" % str(res_valid.errors))

	var invalid_dict: Dictionary = {
		"id": "", # Missing ID
		"geometry": {
			"width": { "min": 20, "max": 10 } # Min > Max
		},
		"entrances": {
			"allowed_sides": ["invalid_cardinal_direction"]
		}
	}

	var res_invalid = validator.validate_definition(invalid_dict)
	assert(not res_invalid.is_valid, "FAIL: invalid template definition must fail validation")
	assert(res_invalid.errors.size() >= 3, "FAIL: expected at least 3 validation errors, got %d" % res_invalid.errors.size())

	# Test loader rejection of invalid definition
	var loader := _LoaderScript.new()
	var template_from_invalid = loader.parse_template_dictionary(invalid_dict)
	assert(template_from_invalid == null, "FAIL: loader must return null for invalid template definition")

	var template_from_valid = loader.parse_template_dictionary(valid_dict)
	assert(template_from_valid != null, "FAIL: loader must return valid RoomTemplate for valid definition")

	print("PASS: test_room_template_definition_validator passed successfully!")
	quit(0)
