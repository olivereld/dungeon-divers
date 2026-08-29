extends SceneTree

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _ClearancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")
const _SymmetryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_data_contracts ---")
	var data: Dictionary = {
		"id": "sacristy_chamber",
		"display_name": "Sacristy Chamber",
		"tags": ["ceremonial", "sacred"],
		"semantic_constraints": {
			"preferred_purposes": ["sacristy"],
			"allowed_purposes": ["chapel", "sanctum"]
		},
		"geometry": {
			"shape": { "allowed": ["cruciform", "rectangle"] },
			"width": { "min": 8, "max": 14 },
			"depth": { "min": 8, "max": 14 },
			"area": { "min": 64, "max": 196 }
		},
		"entrances": {
			"min": 1, "max": 3,
			"allowed_sides": ["south", "east", "west"],
			"allow_corner": false, "min_spacing": 2
		},
		"clearances": {
			"entrance": 1,
			"focal": 2
		},
		"symmetry": {
			"required": true,
			"axis": "vertical"
		}
	}

	var tpl = _RoomTemplateScript.from_dictionary(data)
	assert(tpl != null, "FAIL: template should parse successfully")
	assert(tpl.id == &"sacristy_chamber", "FAIL: template id mismatch")
	assert(tpl.preferred_purposes.has(&"sacristy"), "FAIL: preferred purpose mismatch")
	assert(tpl.geometry.min_width == 8, "FAIL: min_width mismatch")
	assert(tpl.entrances.allows_side(&"south"), "FAIL: allows_side mismatch")
	assert(not tpl.entrances.allows_side(&"north"), "FAIL: north should not be allowed")
	assert(tpl.clearances.focal == 2, "FAIL: clearances focal mismatch")
	assert(tpl.symmetry.axis == &"vertical", "FAIL: symmetry axis mismatch")
	assert(tpl.symmetry.required == true, "FAIL: symmetry required mismatch")

	print("PASS: test_room_template_data_contracts passed successfully!")
	quit(0)
