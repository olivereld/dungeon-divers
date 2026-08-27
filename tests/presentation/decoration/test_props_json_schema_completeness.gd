extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_props_json_schema_completeness ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var file_path := "res://resources/dungeon_profiles/assets/props.json"
	assert(FileAccess.file_exists(file_path), "FAIL: props.json must exist")

	var f := FileAccess.open(file_path, FileAccess.READ)
	var json_str := f.get_as_text()
	f.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	assert(err == OK, "FAIL: props.json must be valid JSON: " + json.get_error_message())

	var data = json.get_data()
	assert(data is Dictionary, "FAIL: root must be dictionary")
	assert(data.has("props") and data["props"] is Dictionary, "FAIL: props.json must contain 'props' dict")

	var props: Dictionary = data["props"]
	print("  Found %d props defined in props.json" % props.size())
	assert(props.size() >= 15, "FAIL: props.json should contain at least 15 comprehensive prop definitions")

	var required_keys := ["id", "source", "tags", "footprint", "collision", "placement", "scale"]

	for prop_id in props.keys():
		var pdef = props[prop_id]
		assert(pdef is Dictionary, "FAIL: prop %s must be a Dictionary" % str(prop_id))

		for r_key in required_keys:
			assert(pdef.has(r_key), "FAIL: prop '%s' is missing required schema key '%s'" % [str(prop_id), r_key])

		var src = pdef["source"]
		assert(src is Dictionary, "FAIL: prop '%s' source must be a Dictionary" % str(prop_id))
		assert(src.has("type"), "FAIL: prop '%s' source must have 'type'" % str(prop_id))

		var st_type = str(src["type"]).to_lower()
		assert(st_type == "procedural" or st_type == "packed_scene", "FAIL: prop '%s' source type must be 'procedural' or 'packed_scene', got '%s'" % [str(prop_id), st_type])

		if st_type == "procedural":
			assert(src.has("builder_id"), "FAIL: procedural prop '%s' must have 'builder_id'" % str(prop_id))
		elif st_type == "packed_scene":
			assert(src.has("scene"), "FAIL: packed_scene prop '%s' must have 'scene'" % str(prop_id))

		print("  [OK] Prop '%s' valid (%s)" % [str(prop_id), st_type])

	print("==================================================================")
	print("[PASS] test_props_json_schema_completeness passed with 100% success!")
	print("==================================================================")
	quit(0)
