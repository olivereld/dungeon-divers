extends SceneTree

const _ResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _ProfileRoomTemplateConstraintsScript = preload("res://src/dungeon_generator/profiles/profile_room_template_constraints.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_resolver ---")
	var reg := _RegistryScript.new()
	var geom_valid := _GeometryPolicyScript.new([&"chapel"], 6, 20, 6, 20, 36, 400)
	var ent_valid := _EntrancePolicyScript.new(1, 4, [&"north", &"south", &"east", &"west"])
	var tpl_chapel := _RoomTemplateScript.new(&"chapel", "Chapel", [&"ceremonial"], geom_valid, ent_valid, null, {}, null, [&"sacristy"], [&"sacristy"])
	reg.register_template(tpl_chapel)

	var geom_oct := _GeometryPolicyScript.new([&"octagonal"], 8, 20, 8, 20, 64, 400)
	var ent_oct := _EntrancePolicyScript.new(1, 4, [&"north", &"south", &"east", &"west"])
	var tpl_oct := _RoomTemplateScript.new(&"octagonal_chamber", "Octagon", [&"crypt"], geom_oct, ent_oct, null, {}, null, [&"crypt", &"sacristy"], [])
	reg.register_template(tpl_oct)

	var resolver := _ResolverScript.new(reg)
	
	# Test 1: Resolve matching preferred template from ProfileRoom constraints
	var tc := _ProfileRoomTemplateConstraintsScript.new([&"chapel", &"octagonal_chamber"], [&"chapel"], [], [&"ceremonial"])
	var profile := _ProfileRoomScript.new(&"sacristy", "Sacristy", 1, null, null, null, null, [], tc)
	var room := RoomData.new(1, Rect2i(5, 5, 10, 10), &"sacristy")
	var entrances: Array[Vector2i] = [Vector2i(10, 5)] # north entrance
	
	var resolved = resolver.resolve_template(room, profile, entrances, 12345)
	assert(resolved != null, "FAIL: should resolve a valid template")
	assert(resolved.id == &"chapel", "FAIL: resolved template should be chapel (preferred)")

	# Test 2: Incompatible dimensions for chapel (e.g. 5x5 when min is 6x6)
	var small_room := RoomData.new(2, Rect2i(5, 5, 5, 5), &"sacristy")
	var fallback_res = resolver.resolve_template(small_room, profile, entrances, 12345)
	assert(fallback_res != null, "FAIL: fallback template must never be null")
	assert(fallback_res.id == &"procedural_fallback", "FAIL: should fallback when dimensions are incompatible")

	# Test 3: Determinism across identical seed
	var res_a = resolver.resolve_template(room, profile, entrances, 9999)
	var res_b = resolver.resolve_template(room, profile, entrances, 9999)
	assert(res_a.id == res_b.id, "FAIL: resolution must be deterministic for identical seeds")

	print("PASS: test_room_template_resolver passed successfully!")
	quit(0)
