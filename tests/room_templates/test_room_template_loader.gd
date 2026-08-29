extends SceneTree

## Test unitario del cargador JSON de RoomTemplates

const _LoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_loader ---")
	var loader := _LoaderScript.new()

	# 1. Cargar sacristy_template.json
	var sacristy = loader.load_from_file("res://resources/dungeon_profiles/room_templates/crypt/sacristy_template.json")
	assert(sacristy != null, "FAIL: must load sacristy_template.json")
	assert(sacristy.id == &"sacristy_template", "FAIL: template id mismatch")
	assert(sacristy.geometry.min_width == 7 and sacristy.geometry.max_width == 13, "FAIL: geometry mismatch")
	assert(sacristy.symmetry.required == true and sacristy.symmetry.axis == &"vertical", "FAIL: symmetry mismatch")
	assert(sacristy.has_anchor(&"focal") and sacristy.has_anchor(&"altar"), "FAIL: anchors mismatch")
	assert(sacristy.is_purpose_allowed(&"sacristy"), "FAIL: purpose sacristy must be allowed")

	# 2. Cargar chapel_template.json
	var chapel = loader.load_from_file("res://resources/dungeon_profiles/room_templates/crypt/chapel_template.json")
	assert(chapel != null, "FAIL: must load chapel_template.json")
	assert(chapel.entrances.allowed_sides.size() == 2, "FAIL: chapel entrance sides mismatch")

	# 3. Cargar rectangular_chamber_template.json
	var chamber = loader.load_from_file("res://resources/dungeon_profiles/room_templates/generic/rectangular_chamber_template.json")
	assert(chamber != null, "FAIL: must load rectangular_chamber_template.json")
	assert(chamber.geometry.min_width == 5 and chamber.geometry.max_width == 15, "FAIL: chamber geometry mismatch")

	print("PASS: test_room_template_loader passed successfully!")
	quit(0)
