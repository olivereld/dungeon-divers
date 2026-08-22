extends SceneTree

const PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_profile_resolver ---")
	print("==================================================================")

	var resolver := PresentationProfileResolverScript.new()

	# 1. MAUSOLEUM + CRYPT
	var maus_crypt = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.CRYPT)
	assert(maus_crypt != null, "FAIL: maus_crypt must not be null")
	assert(maus_crypt.wall_style == ArchitecturalStyleScript.WallStyle.DARK_STONE)
	assert(maus_crypt.floor_style == ArchitecturalStyleScript.FloorStyle.RUINED_STONE)
	assert(maus_crypt.door_style == ArchitecturalStyleScript.DoorStyle.STONE_ARCH)
	assert(maus_crypt.decoration_palette == ArchitecturalStyleScript.DecorationPalette.CRYPT)

	# 2. FORTRESS + ARMORY
	var fort_armory = resolver.resolve(DungeonArchetypeScript.Type.FORTRESS, RoomPurposeScript.Type.ARMORY)
	assert(fort_armory != null, "FAIL: fort_armory must not be null")
	assert(fort_armory.wall_style == ArchitecturalStyleScript.WallStyle.FORTRESS_STONE)
	assert(fort_armory.floor_style == ArchitecturalStyleScript.FloorStyle.COBBLESTONE or fort_armory.floor_style == ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS)
	assert(fort_armory.decoration_palette == ArchitecturalStyleScript.DecorationPalette.ARMORY)

	# 3. MINE + EXCAVATION
	var mine_exc = resolver.resolve(DungeonArchetypeScript.Type.MINE, RoomPurposeScript.Type.EXCAVATION)
	assert(mine_exc != null, "FAIL: mine_exc must not be null")
	assert(mine_exc.wall_style == ArchitecturalStyleScript.WallStyle.MINE_ROCK)
	assert(mine_exc.floor_style == ArchitecturalStyleScript.FloorStyle.MINE_ROCK)
	assert(mine_exc.decoration_palette == ArchitecturalStyleScript.DecorationPalette.MINE)

	# 4. TEMPLE + SANCTUM
	var temple_sanc = resolver.resolve(DungeonArchetypeScript.Type.TEMPLE, RoomPurposeScript.Type.SANCTUM)
	assert(temple_sanc != null, "FAIL: temple_sanc must not be null")
	assert(temple_sanc.wall_style == ArchitecturalStyleScript.WallStyle.TEMPLE_STONE)
	assert(temple_sanc.floor_style == ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES)
	assert(temple_sanc.decoration_palette == ArchitecturalStyleScript.DecorationPalette.SANCTUM)

	# 5. Determinismo
	var maus_crypt_2 = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.CRYPT)
	assert(maus_crypt.equals(maus_crypt_2), "FAIL: PresentationProfileResolver must be 100% deterministic")

	print("  [OK] PresentationProfileResolver correctly resolves all archetype x purpose combinations.")
	print("  [OK] Determinism verified.")
	print("[PASS] test_presentation_profile_resolver completed successfully.")
	quit(0)
