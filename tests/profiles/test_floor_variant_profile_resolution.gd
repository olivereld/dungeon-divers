extends SceneTree

const _LoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")

func _init() -> void:
	print("--- Running test_floor_variant_profile_resolution ---")
	var loader = _LoaderScript.new()
	var validator = _ValidatorScript.new()

	var json_str = """{
		"schema_version": 2,
		"id": "tomb_test",
		"display_name": "Tomb Test",
		"architecture": {
			"floor": {
				"base": "catacomb_dirt",
				"variants": [
					{ "style": "ruined_stone", "weight": 15.0 },
					{ "style": "cracked_dirt", "weight": 5.0 }
				]
			},
			"walls": "dark_stone",
			"door": "stone_arch",
			"stairs": "stone"
		}
	}"""
	var room_prof = loader.parse_room_from_json_string(json_str)
	assert(room_prof != null, "Room profile parse failed")
	assert(room_prof.architecture.floor == &"catacomb_dirt", "Base floor mismatch")
	assert(room_prof.architecture.floor_variants != null, "Floor variants policy missing")
	assert(room_prof.architecture.floor_variants.variants.size() == 2, "Variants size mismatch")

	var val_res = validator.validate_room(room_prof)
	assert(val_res.is_valid, "Validation failed: %s" % str(val_res.errors))
	print("  [OK] Floor variant parsing and validation passed")
	print("[PASS] test_floor_variant_profile_resolution passed!")
	quit(0)
