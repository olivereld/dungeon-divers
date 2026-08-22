extends SceneTree

const PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_profile ---")
	print("==================================================================")

	var resolver := PresentationProfileResolverScript.new()

	# 1. Validar TOMB
	var prof_tomb = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB)
	assert(prof_tomb != null, "FAIL: Tomb profile is null")
	assert(prof_tomb.floor_style == ArchitecturalStyleScript.FloorStyle.RUINED_STONE, "FAIL: Tomb floor mismatch")
	assert(prof_tomb.wall_style == ArchitecturalStyleScript.WallStyle.DARK_STONE, "FAIL: Tomb wall mismatch")
	assert(prof_tomb.fixture_style == ArchitecturalStyleScript.FixtureStyle.TORCH, "FAIL: Tomb fixture mismatch")
	print("  [OK] TOMB architectural profile verified.")

	# 2. Validar SACRISTY
	var prof_sacristy = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.SACRISTY)
	assert(prof_sacristy != null, "FAIL: Sacristy profile is null")
	assert(prof_sacristy.floor_style == ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS, "FAIL: Sacristy floor mismatch")
	assert(prof_sacristy.fixture_style == ArchitecturalStyleScript.FixtureStyle.CANDLE_CLUSTER, "FAIL: Sacristy fixture mismatch")
	print("  [OK] SACRISTY architectural profile verified.")

	# 3. Validar MORTUARY
	var prof_mortuary = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.MORTUARY)
	assert(prof_mortuary != null, "FAIL: Mortuary profile is null")
	assert(prof_mortuary.floor_style == ArchitecturalStyleScript.FloorStyle.RUINED_STONE, "FAIL: Mortuary floor mismatch")
	assert(prof_mortuary.fixture_style == ArchitecturalStyleScript.FixtureStyle.BRAZIER, "FAIL: Mortuary fixture mismatch")
	print("  [OK] MORTUARY architectural profile verified.")

	# 4. Validar ANTECHAMBER
	var prof_ante = resolver.resolve(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.ANTECHAMBER)
	assert(prof_ante != null, "FAIL: Antechamber profile is null")
	assert(prof_ante.floor_style == ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS, "FAIL: Antechamber floor mismatch")
	assert(prof_ante.fixture_style == ArchitecturalStyleScript.FixtureStyle.LANTERN, "FAIL: Antechamber fixture mismatch")
	print("  [OK] ANTECHAMBER architectural profile verified.")

	print("[PASS] test_crypt_profile completed successfully!")
	quit(0)
