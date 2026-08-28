extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_json_schema ---")
	print("==================================================================")
	var f = FileAccess.open("res://resources/dungeon_profiles/assets/destruction.json", FileAccess.READ)
	assert(f != null, "FAIL: destruction.json must exist")
	var text = f.get_as_text()
	var json = JSON.parse_string(text)
	assert(json is Dictionary, "FAIL: destruction.json must be a Dictionary")
	assert(json.has("destructibles"), "FAIL: destruction.json must have 'destructibles'")
	var d = json["destructibles"]
	assert(d.has("crypt_urn_banded_floor"), "FAIL: must define crypt_urn_banded_floor")
	assert(d.has("skull_pile"), "FAIL: must define skull_pile")
	assert(d.has("candle_cluster"), "FAIL: must define candle_cluster")
	print("  [OK] destruction.json parsed and verified successfully: %d destructibles found." % d.size())
	print("[PASS] test_destruction_json_schema passed with 100% success!")
	print("==================================================================")
	quit(0)
