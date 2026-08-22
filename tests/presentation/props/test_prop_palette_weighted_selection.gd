extends SceneTree

const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_palette_weighted_selection ---")
	print("==================================================================")

	var s_floor1 := PropStyleScript.new(&"floor_common", PropStyleScript.Type.TOMBSTONE, PropPlacementModeScript.Mode.FLOOR)
	var s_floor2 := PropStyleScript.new(&"floor_rare", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.FLOOR)
	var s_wall := PropStyleScript.new(&"wall_shelf", PropStyleScript.Type.BOOKSHELF, PropPlacementModeScript.Mode.WALL)

	var entries: Array[PropPaletteEntryScript] = [
		PropPaletteEntryScript.new(s_floor1, 80.0),
		PropPaletteEntryScript.new(s_floor2, 20.0),
		PropPaletteEntryScript.new(s_wall, 100.0)
	]

	var palette := PropPaletteScript.new(&"test_palette", entries)

	# 1. Test get_entries_for_placement
	var floor_entries = palette.get_entries_for_placement(PropPlacementModeScript.Mode.FLOOR)
	assert(floor_entries.size() == 2, "FAIL: Expected 2 floor entries")

	var wall_entries = palette.get_entries_for_placement(PropPlacementModeScript.Mode.WALL)
	assert(wall_entries.size() == 1, "FAIL: Expected 1 wall entry")

	var center_entries = palette.get_entries_for_placement(PropPlacementModeScript.Mode.CENTER)
	assert(center_entries.is_empty(), "FAIL: Expected 0 center entries")
	print("  [OK] Filtering entries by placement mode validated.")

	# 2. Test Determinism across same seed
	var sel_a = palette.select_weighted(PropPlacementModeScript.Mode.FLOOR, 424242)
	var sel_b = palette.select_weighted(PropPlacementModeScript.Mode.FLOOR, 424242)
	assert(sel_a == sel_b, "FAIL: Weighted selection must be deterministic for identical seeds")
	print("  [OK] Deterministic weighted selection validated.")

	# 3. Test Distribution over 1000 samples
	var count_common: int = 0
	var count_rare: int = 0
	for i in range(1000):
		var picked = palette.select_weighted(PropPlacementModeScript.Mode.FLOOR, i * 31 + 7)
		if picked == s_floor1:
			count_common += 1
		elif picked == s_floor2:
			count_rare += 1

	print("  [OK] Distribution over 1000 rolls: Common=%d (exp ~800), Rare=%d (exp ~200)" % [count_common, count_rare])
	assert(count_common > 700 and count_rare > 100, "FAIL: Weighted distribution skewed")

	print("[PASS] test_prop_palette_weighted_selection completed successfully!")
	quit(0)
