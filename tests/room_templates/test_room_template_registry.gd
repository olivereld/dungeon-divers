extends SceneTree

## Test unitario del registro de RoomTemplates

const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_registry ---")
	var registry := _RegistryScript.new()

	# 1. Autodescubrimiento recursivo de templates en res://resources/dungeon_profiles/room_templates/
	var count = registry.discover_templates_in_directory("res://resources/dungeon_profiles/room_templates")
	assert(count >= 7, "FAIL: must discover at least 7 base templates, found %d" % count)
	assert(registry.has_template(&"open_hall"), "FAIL: registry must have open_hall")
	assert(registry.has_template(&"octagonal_chamber"), "FAIL: registry must have octagonal_chamber")
	assert(registry.has_template(&"cruciform_sanctuary"), "FAIL: registry must have cruciform_sanctuary")
	assert(registry.has_template(&"pillared_hall"), "FAIL: registry must have pillared_hall")
	assert(registry.has_template(&"ceremonial_chapel"), "FAIL: registry must have ceremonial_chapel")

	# 2. Lookup y enumeración
	var all_tpls = registry.get_all_templates()
	assert(all_tpls.size() == count, "FAIL: get_all_templates count mismatch")

	var all_ids = registry.list_template_ids()
	assert(all_ids.has(&"open_hall"), "FAIL: list_template_ids missing open_hall")

	var open_hall = registry.get_template(&"open_hall")
	assert(open_hall != null and open_hall.id == &"open_hall", "FAIL: get_template returned incorrect template")

	# 3. Registro dinámico y limpieza
	var custom_tpl := _RoomTemplateScript.new(&"custom_test_tpl", "Custom Test", [&"test"])
	registry.register_template(custom_tpl)
	assert(registry.has_template(&"custom_test_tpl"), "FAIL: custom template should be registered")

	registry.clear()
	assert(registry.get_all_templates().is_empty(), "FAIL: clear() must empty the registry")

	print("PASS: test_room_template_registry passed successfully!")
	quit(0)
