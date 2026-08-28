extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomProfileResolverScript = preload("res://src/dungeon_generator/profiles/room_profile_resolver.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_profile_resolution ---")

	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: Bundle should load")

	var resolver := _RoomProfileResolverScript.new(bundle)

	# 1. Resolve by StringName
	var crypt_room = resolver.resolve(&"crypt")
	assert(crypt_room != null, "FAIL: Should resolve 'crypt' by StringName")
	assert(crypt_room.id == &"crypt", "FAIL: Resolved room ID must be crypt")

	var tomb_room = resolver.resolve(&"tomb")
	assert(tomb_room != null, "FAIL: Should resolve 'tomb' by StringName")
	assert(tomb_room.id == &"tomb", "FAIL: Resolved room ID must be tomb")

	var royal_tomb = resolver.resolve(&"royal_tomb")
	assert(royal_tomb != null, "FAIL: Should resolve 'royal_tomb' by StringName")
	assert(royal_tomb.id == &"royal_tomb", "FAIL: Resolved room ID must be royal_tomb")

	var sacristy_room = resolver.resolve(&"sacristy")
	assert(sacristy_room != null, "FAIL: Should resolve 'sacristy' by StringName")
	assert(sacristy_room.id == &"sacristy", "FAIL: Resolved room ID must be sacristy")

	var entrance_room = resolver.resolve(&"entrance")
	assert(entrance_room != null, "FAIL: Should resolve 'entrance' by StringName")
	assert(entrance_room.id == &"entrance", "FAIL: Resolved room ID must be entrance")

	# 2. Resolve by StringName / String
	var catacomb_room = resolver.resolve(&"catacomb")
	assert(catacomb_room != null, "FAIL: Should resolve by StringName 'catacomb'")
	assert(catacomb_room.id == &"catacomb", "FAIL: Resolved room ID must be catacomb")

	var hall_room = resolver.resolve("HALL")
	assert(hall_room != null, "FAIL: Should resolve by uppercase string 'HALL'")
	assert(hall_room.id == &"hall", "FAIL: Resolved room ID must be hall")

	# 3. has_profile_for checks
	assert(resolver.has_profile_for(&"crypt"), "FAIL: has_profile_for('crypt') should be true")
	assert(resolver.has_profile_for(&"mortuary"), "FAIL: has_profile_for('mortuary') should be true")
	assert(not resolver.has_profile_for(&"unknown_nonexistent_room"), "FAIL: has_profile_for(unknown) should be false")

	# 4. Fallback on unknown or generic purpose
	var fallback_room = resolver.resolve(&"unknown_purpose_xyz")
	assert(fallback_room != null, "FAIL: Unknown purpose should resolve to fallback without crash")

	var generic_room = resolver.resolve(&"generic")
	assert(generic_room != null, "FAIL: Generic purpose should resolve to fallback room")

	print("[PASS] test_room_profile_resolution completed successfully!")
	quit(0)
