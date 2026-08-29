extends SceneTree

const _RepositoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_repository.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_repository ---")
	var repo := _RepositoryScript.new()

	# 1. Test listing existing canonical catalog templates
	var list = repo.list_templates("res://resources/dungeon_profiles/room_templates")
	assert(list.size() >= 7, "FAIL: repository should find at least 7 base templates, found %d" % list.size())

	var has_open_hall = false
	for item in list:
		if item["id"] == &"open_hall":
			has_open_hall = true
			break
	assert(has_open_hall, "FAIL: open_hall template should be found in catalog")

	# 2. Test loading existing template by ID
	var tpl = repo.load_template_by_id(&"open_hall", "res://resources/dungeon_profiles/room_templates")
	assert(tpl != null, "FAIL: load_template_by_id returned null")
	assert(tpl.id == &"open_hall", "FAIL: template id mismatch")

	# 3. Test dictionary serialization roundtrip
	var dict = repo.template_to_dictionary(tpl)
	assert(dict["id"] == "open_hall", "FAIL: dictionary id mismatch")
	assert(dict.has("geometry"), "FAIL: dictionary missing geometry")
	assert(dict.has("entrances"), "FAIL: dictionary missing entrances")

	# 4. Test clone template
	var cloned = repo.clone_template(tpl, &"cloned_hall", "Cloned Hall")
	assert(cloned != null, "FAIL: clone failed")
	assert(cloned.id == &"cloned_hall", "FAIL: cloned id mismatch")
	assert(cloned.display_name == "Cloned Hall", "FAIL: cloned display_name mismatch")

	print("PASS: test_room_template_repository passed successfully!")
	quit(0)
