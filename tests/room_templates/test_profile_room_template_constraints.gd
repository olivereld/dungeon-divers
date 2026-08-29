extends SceneTree

const _LoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ConstraintsScript = preload("res://src/dungeon_generator/profiles/profile_room_template_constraints.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_profile_room_template_constraints ---")
	var loader := _LoaderScript.new()
	var json_str = """{
		"schema_version": 1,
		"id": "sacristy_test",
		"display_name": "Sacristy",
		"templates": {
			"allowed": ["chapel", "sacristy"],
			"preferred": ["chapel"],
			"forbidden": ["corridor_grid"],
			"required_tags": ["ceremonial"]
		}
	}"""
	var room = loader.load_room_from_json_string(json_str)
	assert(room != null, "FAIL: room should parse")
	assert(room.template_constraints != null, "FAIL: template_constraints must not be null")
	assert(room.template_constraints.is_template_allowed(&"chapel") == true, "FAIL: chapel should be allowed")
	assert(room.template_constraints.is_template_allowed(&"sacristy") == true, "FAIL: sacristy should be allowed")
	assert(room.template_constraints.is_template_allowed(&"random_room") == false, "FAIL: random_room should not be allowed")
	assert(room.template_constraints.is_template_forbidden(&"corridor_grid") == true, "FAIL: corridor_grid should be forbidden")
	assert(room.template_constraints.preferred_templates.has(&"chapel"), "FAIL: preferred should contain chapel")
	assert(room.template_constraints.required_tags.has(&"ceremonial"), "FAIL: required_tags should contain ceremonial")

	# Test empty constraints fallback (allows everything)
	var empty_json = """{ "id": "generic_room", "display_name": "Generic" }"""
	var empty_room = loader.load_room_from_json_string(empty_json)
	assert(empty_room != null, "FAIL: empty room should parse")
	assert(empty_room.template_constraints != null, "FAIL: empty room should have default constraints")
	assert(empty_room.template_constraints.is_template_allowed(&"any_template") == true, "FAIL: empty constraints should allow any template")
	
	print("PASS: test_profile_room_template_constraints passed successfully!")
	quit(0)
