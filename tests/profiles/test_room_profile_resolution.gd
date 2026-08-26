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

	# 1. Resolve by enum / int
	var crypt_room = resolver.resolve(_RoomPurposeScript.Type.CRYPT)
	assert(crypt_room != null, "FAIL: Should resolve CRYPT by enum")
	assert(crypt_room.id == &"crypt", "FAIL: Resolved room ID must be crypt")

	var tomb_room = resolver.resolve(_RoomPurposeScript.Type.TOMB)
	assert(tomb_room != null, "FAIL: Should resolve TOMB by enum")
	assert(tomb_room.id == &"tomb", "FAIL: Resolved room ID must be tomb")

	var royal_tomb = resolver.resolve(_RoomPurposeScript.Type.ROYAL_TOMB)
	assert(royal_tomb != null, "FAIL: Should resolve ROYAL_TOMB by enum")
	assert(royal_tomb.id == &"royal_tomb", "FAIL: Resolved room ID must be royal_tomb")

	var sacristy_room = resolver.resolve(_RoomPurposeScript.Type.SACRISTY)
	assert(sacristy_room != null, "FAIL: Should resolve SACRISTY by enum")
	assert(sacristy_room.id == &"sacristy", "FAIL: Resolved room ID must be sacristy")

	var entrance_room = resolver.resolve(_RoomPurposeScript.Type.ENTRANCE)
	assert(entrance_room != null, "FAIL: Should resolve ENTRANCE by enum")
	assert(entrance_room.id == &"entrance", "FAIL: Resolved room ID must be entrance")

	# 2. Resolve by StringName / String
	var catacomb_room = resolver.resolve(&"catacomb")
	assert(catacomb_room != null, "FAIL: Should resolve by StringName 'catacomb'")
	assert(catacomb_room.id == &"catacomb", "FAIL: Resolved room ID must be catacomb")

	var hall_room = resolver.resolve("HALL")
	assert(hall_room != null, "FAIL: Should resolve by uppercase string 'HALL'")
	assert(hall_room.id == &"hall", "FAIL: Resolved room ID must be hall")

	# 3. has_profile_for checks
	assert(resolver.has_profile_for(_RoomPurposeScript.Type.CRYPT), "FAIL: has_profile_for(CRYPT) should be true")
	assert(resolver.has_profile_for(&"mortuary"), "FAIL: has_profile_for('mortuary') should be true")
	assert(not resolver.has_profile_for(&"unknown_nonexistent_room"), "FAIL: has_profile_for(unknown) should be false")

	# 4. Fallback on unknown or generic purpose
	var fallback_room = resolver.resolve(9999) # Unknown purpose enum
	assert(fallback_room != null, "FAIL: Unknown purpose should resolve to fallback without crash")

	var generic_room = resolver.resolve(_RoomPurposeScript.Type.GENERIC)
	assert(generic_room != null, "FAIL: Generic purpose should resolve to fallback room")

	print("[PASS] test_room_profile_resolution completed successfully!")
	quit(0)
