extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_catalogs_schema ---")
	print("==================================================================")

	var debris_file = FileAccess.open("res://resources/dungeon_profiles/assets/debris.json", FileAccess.READ)
	assert(debris_file != null, "FAIL: debris.json must exist")
	var debris_json = JSON.parse_string(debris_file.get_as_text())
	assert(debris_json is Dictionary and debris_json.has("debris"), "FAIL: debris.json schema invalid")
	assert(debris_json["debris"].has("ceramic_small"), "FAIL: ceramic_small debris required")
	assert(debris_json["debris"].has("bones_small"), "FAIL: bones_small debris required")
	assert(debris_json["debris"].has("wood_splinters"), "FAIL: wood_splinters debris required")
	assert(debris_json["debris"].has("stone_fragments"), "FAIL: stone_fragments debris required")

	var effects_file = FileAccess.open("res://resources/dungeon_profiles/assets/effects.json", FileAccess.READ)
	assert(effects_file != null, "FAIL: effects.json must exist")
	var effects_json = JSON.parse_string(effects_file.get_as_text())
	assert(effects_json is Dictionary and effects_json.has("effects"), "FAIL: effects.json schema invalid")
	assert(effects_json["effects"].has("dust_small"), "FAIL: dust_small effect required")
	assert(effects_json["effects"].has("ceramic_break"), "FAIL: ceramic_break effect required")
	assert(effects_json["effects"].has("bone_scatter"), "FAIL: bone_scatter effect required")
	assert(effects_json["effects"].has("smoke_puff"), "FAIL: smoke_puff effect required")

	print("[PASS] test_destruction_catalogs_schema passed 100%!")
	print("==================================================================")
	quit(0)
