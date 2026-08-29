extends SceneTree

## Test unitario de contratos y modelos de RoomTemplate

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _SymmetryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")
const _ClearancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")
const _SchemaScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_schema.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_contracts ---")

	# 1. Geometry Policy
	var geom := _GeometryPolicyScript.new([&"rectangle", &"square"], 7, 13, 7, 15, 49, 195, 0.65, 1.5)
	assert(geom.allows_shape(&"rectangle"), "FAIL: geometry must allow rectangle")
	assert(geom.allows_shape(&"square"), "FAIL: geometry must allow square")
	assert(not geom.allows_shape(&"circle"), "FAIL: geometry must reject circle")
	assert(geom.min_width == 7 and geom.max_width == 13, "FAIL: width bounds incorrect")

	# 2. Entrance Policy
	var ent := _EntrancePolicyScript.new(1, 3, [&"north", &"south"], false, 3)
	assert(ent.min_count == 1 and ent.max_count == 3, "FAIL: entrance bounds incorrect")
	assert(ent.allows_side(&"north") and not ent.allows_side(&"east"), "FAIL: entrance sides incorrect")
	assert(ent.min_spacing == 3, "FAIL: min spacing incorrect")

	# 3. Symmetry Policy
	var sym := _SymmetryPolicyScript.new(true, &"vertical", 0)
	assert(sym.required == true and sym.axis == &"vertical", "FAIL: symmetry policy incorrect")

	# 4. Anchor Def
	var anchor := _AnchorDefScript.new(&"altar", true, &"opposite_entrance")
	assert(anchor.id == &"altar" and anchor.location_hint == &"opposite_entrance", "FAIL: anchor def incorrect")

	# 5. Clearance Policy
	var clr := _ClearancePolicyScript.new(2, 2, 1, 0)
	assert(clr.entrance == 2 and clr.focal == 2 and clr.circulation == 1, "FAIL: clearance policy incorrect")

	# 6. RoomTemplate Root Model
	var tpl := _RoomTemplateScript.new(
		&"sacristy",
		"Sacristy",
		[&"ceremonial", &"focal"],
		geom,
		ent,
		sym,
		{ &"altar": anchor },
		clr,
		[&"ceremonial", &"storage"],
		[&"ceremonial"]
	)
	assert(tpl.id == &"sacristy", "FAIL: template id incorrect")
	assert(tpl.has_anchor(&"altar"), "FAIL: must have altar anchor")
	assert(tpl.is_purpose_allowed(&"ceremonial"), "FAIL: purpose ceremonial should be allowed")
	assert(not tpl.is_purpose_allowed(&"barracks"), "FAIL: purpose barracks should be rejected")

	# 7. Schema Validation
	var raw_valid = {
		"id": "sacristy",
		"geometry": {
			"width": { "min": 5, "max": 10 },
			"depth": { "min": 5, "max": 10 }
		}
	}
	var errs = _SchemaScript.validate_raw_dict(raw_valid)
	assert(errs.is_empty(), "FAIL: valid dict should have zero errors")

	var raw_invalid = {
		"id": "",
		"geometry": {
			"width": { "min": 15, "max": 5 }
		}
	}
	var errs_inv = _SchemaScript.validate_raw_dict(raw_invalid)
	assert(errs_inv.size() >= 2, "FAIL: invalid dict should have errors")

	print("PASS: test_room_template_contracts passed successfully!")
	quit(0)
