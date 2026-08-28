extends SceneTree

const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_archetype_contracts ---")
	print("==================================================================")

	# 1. Verificar enum DungeonArchetype
	assert(DungeonArchetypeScript.Type.GENERIC == 0, "FAIL: GENERIC must be 0")
	assert(DungeonArchetypeScript.Type.MAUSOLEUM == 1, "FAIL: MAUSOLEUM must be 1")
	assert(DungeonArchetypeScript.Type.FORTRESS == 2, "FAIL: FORTRESS must be 2")
	assert(DungeonArchetypeScript.Type.TEMPLE == 3, "FAIL: TEMPLE must be 3")
	assert(DungeonArchetypeScript.Type.MINE == 4, "FAIL: MINE must be 4")

	assert(DungeonArchetypeScript.to_name(DungeonArchetypeScript.Type.FORTRESS) == "FORTRESS")
	assert(DungeonArchetypeScript.from_name("FORTRESS") == DungeonArchetypeScript.Type.FORTRESS)
	assert(DungeonArchetypeScript.from_name("mausoleum") == DungeonArchetypeScript.Type.MAUSOLEUM)

	# 2. Verificar enum RoomPurpose
	assert(RoomPurposeScript.Type.ENTRANCE != null)
	assert(RoomPurposeScript.Type.ARMORY != null)
	assert(RoomPurposeScript.Type.CRYPT != null)
	assert(RoomPurposeScript.Type.THRONE_ROOM != null)
	assert(RoomPurposeScript.Type.SHRINE != null)
	assert(RoomPurposeScript.Type.FORGE != null)

	assert(RoomPurposeScript.to_name(RoomPurposeScript.Type.ARMORY) == "ARMORY")
	assert(RoomPurposeScript.from_name("ARMORY") == RoomPurposeScript.Type.ARMORY)
	assert(RoomPurposeScript.from_name("throne_room") == RoomPurposeScript.Type.THRONE_ROOM)

	# 3. Verificar Archetype Profiles vía ProfileLoader y ArchetypeCatalog
	var loader = ProfileLoaderScript.new()
	var ids = loader.list_available_archetypes()
	assert(ids.size() > 0, "FAIL: Must have registered archetypes")
	for arch_id in ids:
		var bundle = loader.load_full_archetype_bundle(str(arch_id))
		assert(bundle != null and bundle.archetype != null, "FAIL: Profile must exist for %s" % str(arch_id))
		assert(not bundle.archetype.purpose_weights.is_empty(), "FAIL: Weights cannot be empty")
		assert(bundle.archetype.get_allowed_purposes_for_gameplay(&"BOSS").size() > 0)
		assert(bundle.archetype.get_allowed_purposes_for_gameplay(&"START").size() > 0)
		assert(bundle.archetype.get_allowed_purposes_for_gameplay(&"TREASURE").size() > 0)
		assert(bundle.archetype.get_allowed_purposes_for_gameplay(&"COMBAT").size() > 0)

	print("  [OK] DungeonArchetype and RoomPurpose contracts verified.")
	print("  [OK] Data-driven Archetype Profiles verified.")
	print("[PASS] test_dungeon_archetype_contracts completed successfully.")
	quit(0)
