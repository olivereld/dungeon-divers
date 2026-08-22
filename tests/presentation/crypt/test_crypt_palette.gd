extends SceneTree

const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_palette ---")
	print("==================================================================")

	var resolver := DecorationPaletteResolverScript.new()

	# 1. TOMB Palette
	var pal_tomb = resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB)
	assert(pal_tomb != null and pal_tomb.props != null, "FAIL: Tomb palette is null")
	var focal_tomb = _get_entries_by_role(pal_tomb.props.entries, DecorationRoleScript.Role.FOCAL)
	var support_tomb = _get_entries_by_role(pal_tomb.props.entries, DecorationRoleScript.Role.SUPPORT)
	assert(not focal_tomb.is_empty(), "FAIL: Expected FOCAL props (Sarcophagus) in TOMB palette")
	assert(not support_tomb.is_empty(), "FAIL: Expected SUPPORT props (Tombstones) in TOMB palette")
	print("  [OK] TOMB decoration palette verified (Focal: %d, Support: %d)." % [focal_tomb.size(), support_tomb.size()])

	# 2. SACRISTY Palette
	var pal_sacristy = resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.SACRISTY)
	assert(pal_sacristy != null and pal_sacristy.props != null, "FAIL: Sacristy palette is null")
	var focal_sac = _get_entries_by_role(pal_sacristy.props.entries, DecorationRoleScript.Role.FOCAL)
	var support_sac = _get_entries_by_role(pal_sacristy.props.entries, DecorationRoleScript.Role.SUPPORT)
	assert(not focal_sac.is_empty(), "FAIL: Expected FOCAL props (Altar) in SACRISTY palette")
	assert(not support_sac.is_empty(), "FAIL: Expected SUPPORT props (Pews) in SACRISTY palette")
	print("  [OK] SACRISTY decoration palette verified (Focal: %d, Support: %d)." % [focal_sac.size(), support_sac.size()])

	# 3. MORTUARY Palette
	var pal_mortuary = resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.MORTUARY)
	assert(pal_mortuary != null and pal_mortuary.props != null, "FAIL: Mortuary palette is null")
	var focal_mort = _get_entries_by_role(pal_mortuary.props.entries, DecorationRoleScript.Role.FOCAL)
	assert(not focal_mort.is_empty(), "FAIL: Expected FOCAL props (Altar) in MORTUARY palette")
	print("  [OK] MORTUARY decoration palette verified.")

	# 4. ANTECHAMBER Palette
	var pal_ante = resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.GENERIC)
	assert(pal_ante != null and pal_ante.props != null, "FAIL: Antechamber palette is null")
	var support_ante = _get_entries_by_role(pal_ante.props.entries, DecorationRoleScript.Role.SUPPORT)
	assert(not support_ante.is_empty(), "FAIL: Expected SUPPORT props (Pews/Benches) in ANTECHAMBER palette")
	print("  [OK] ANTECHAMBER decoration palette verified.")

	print("[PASS] test_crypt_palette completed successfully!")
	quit(0)

func _get_entries_by_role(entries: Array, role: int) -> Array:
	var result: Array = []
	for e in entries:
		if e.style != null and e.style.role == role:
			result.append(e)
	return result
