extends SceneTree

const _LoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")
const _DefValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_canonical_base_templates ---")
	var loader := _LoaderScript.new()
	var def_validator := _DefValidatorScript.new()

	var template_files: Array[String] = [
		"res://resources/dungeon_profiles/room_templates/generic/open_hall_template.json",
		"res://resources/dungeon_profiles/room_templates/generic/octagonal_chamber_template.json",
		"res://resources/dungeon_profiles/room_templates/generic/cruciform_sanctuary_template.json",
		"res://resources/dungeon_profiles/room_templates/generic/pillared_hall_template.json",
		"res://resources/dungeon_profiles/room_templates/ceremonial/ceremonial_chapel_template.json",
		"res://resources/dungeon_profiles/room_templates/necropolis/catacomb_gallery_template.json",
		"res://resources/dungeon_profiles/room_templates/necropolis/ossuary_hall_template.json"
	]

	for path in template_files:
		assert(FileAccess.file_exists(path), "FAIL: template file not found: %s" % path)
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		var parse_err = json.parse(file.get_as_text())
		assert(parse_err == OK, "FAIL: json parsing error in %s" % path)

		var data = json.get_data()
		assert(data is Dictionary, "FAIL: expected dictionary in %s" % path)

		var val_res = def_validator.validate_definition(data)
		assert(val_res.is_valid, "FAIL: validation error in %s: %s" % [path, str(val_res.errors)])

		var tpl = loader.load_from_file(path)
		assert(tpl != null, "FAIL: template could not be loaded: %s" % path)
		assert(not tpl.id.is_empty(), "FAIL: template id is empty in %s" % path)
		assert(tpl.geometry != null, "FAIL: template geometry is null in %s" % path)
		assert(not tpl.geometry.allowed_shapes.is_empty(), "FAIL: allowed_shapes is empty in %s" % path)
		assert(tpl.entrances != null, "FAIL: entrances is null in %s" % path)
		assert(tpl.clearances != null, "FAIL: clearances is null in %s" % path)
		print("  [OK] Loaded template: %s (%s)" % [str(tpl.id), path.get_file()])

	print("PASS: test_canonical_base_templates passed successfully!")
	quit(0)
