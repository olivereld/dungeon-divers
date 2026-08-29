extends SceneTree

const _ResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeomPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_resolver_priorities ---")
	var reg := _RegistryScript.new()
	var geom := _GeomPolicyScript.new([&"rectangle"], 6, 12, 6, 12, 36, 144)
	var ent := _EntPolicyScript.new(1, 4, [&"north", &"south", &"east", &"west"])

	var tpl_generic := _RoomTemplateScript.new(&"generic_hall", "Generic Hall", [&"generic"], geom, ent)
	var tpl_specific := _RoomTemplateScript.new(&"crypt_hall", "Crypt Hall", [&"necropolis"], geom, ent)
	tpl_specific.preferred_purposes = [&"crypt"]

	reg.register_template(tpl_generic)
	reg.register_template(tpl_specific)

	var resolver := _ResolverScript.new(reg)
	var room_crypt := RoomData.new(1, Rect2i(0, 0, 8, 8), &"crypt")

	var chosen = resolver.resolve_template(room_crypt, null, [Vector2i(0, 4)], 12345)
	assert(chosen != null, "FAIL: resolver must return a template")
	assert(chosen.id == &"crypt_hall", "FAIL: specific purpose template should take priority over generic, got %s" % str(chosen.id))

	print("PASS: test_room_template_resolver_priorities passed successfully!")
	quit(0)
