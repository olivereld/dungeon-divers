extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_canonical_template_catalog ---")
	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_bundle("res://resources/dungeon_profiles/archetypes/necropolis.json")
	assert(bundle != null, "FAIL: bundle must load")
	assert(bundle.template_registry != null, "FAIL: template_registry must exist")

	var reg = bundle.template_registry
	var expected_templates: Array[StringName] = [
		&"open_hall",
		&"pillared_hall",
		&"octagonal_chamber",
		&"ceremonial_sanctum",
		&"ceremonial_sacristy",
		&"ceremonial_chapel",
		&"crypt_chamber",
		&"ossuary_hall",
		&"royal_mausoleum",
		&"catacomb_gallery"
	]

	for t_id in expected_templates:
		var tpl = reg.get_template(t_id)
		assert(tpl != null, "FAIL: expected template '%s' not registered" % str(t_id))
		assert(tpl.geometry != null, "FAIL: template '%s' missing geometry" % str(t_id))
		assert(tpl.entrances != null, "FAIL: template '%s' missing entrances" % str(t_id))
		assert(tpl.clearances != null, "FAIL: template '%s' missing clearances" % str(t_id))
		assert(tpl.symmetry != null, "FAIL: template '%s' missing symmetry" % str(t_id))

	print("PASS: test_canonical_template_catalog passed successfully!")
	quit(0)
