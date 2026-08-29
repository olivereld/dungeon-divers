extends SceneTree

## Test unitario del registro y emparejador de RoomTemplates

const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _MatcherScript = preload("res://src/dungeon_generator/core/room_templates/matcher/room_template_matcher.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_registry ---")
	var registry := _RegistryScript.new()

	# 1. Autodescubrimiento de templates en res://resources/dungeon_profiles/room_templates/
	var count = registry.discover_templates_in_directory("res://resources/dungeon_profiles/room_templates")
	assert(count >= 3, "FAIL: must discover at least 3 templates, found %d" % count)
	assert(registry.has_template(&"sacristy_template"), "FAIL: registry must have sacristy_template")
	assert(registry.has_template(&"chapel_template"), "FAIL: registry must have chapel_template")
	assert(registry.has_template(&"rectangular_chamber_template"), "FAIL: registry must have rectangular_chamber_template")

	# 2. Matcher: Emparejar propósito 'sacristy'
	var matcher := _MatcherScript.new(registry)
	var matched_sacristy = matcher.match_template_for_purpose(&"sacristy")
	assert(matched_sacristy != null, "FAIL: must match template for sacristy")
	assert(matched_sacristy.id == &"sacristy_template", "FAIL: matched template must be sacristy_template, got %s" % str(matched_sacristy.id))

	# 3. Matcher: Emparejar propósito desconocido (debe caer en rectangular_chamber_template genérico)
	var matched_generic = matcher.match_template_for_purpose(&"unknown_dungeon_room")
	assert(matched_generic != null, "FAIL: must match fallback generic template")
	assert(matched_generic.id == &"rectangular_chamber_template", "FAIL: matched template must be rectangular_chamber_template")

	# 4. Encontrar todas las plantillas compatibles con 'ceremonial'
	var ceremonial_templates = matcher.find_compatible_templates(&"ceremonial")
	assert(ceremonial_templates.size() >= 2, "FAIL: should find at least 2 ceremonial compatible templates")

	print("PASS: test_room_template_registry passed successfully!")
	quit(0)
