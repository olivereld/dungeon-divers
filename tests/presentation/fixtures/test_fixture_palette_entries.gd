extends SceneTree

const FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_palette_entries ---")
	print("==================================================================")

	# 1. Validar FixturePaletteEntry
	var style_torch := FixtureStyleScript.new(
		&"test_torch",
		FixtureStyleScript.Type.TORCH,
		FixturePlacementModeScript.Mode.WALL
	)
	var entry := FixturePaletteEntryScript.new(style_torch, 75.0, 1, 10)
	assert(entry.style == style_torch, "FAIL: Style mismatch in entry")
	assert(is_equal_approx(entry.weight, 75.0), "FAIL: Weight mismatch")
	assert(entry.min_count == 1)
	assert(entry.max_count == 10)
	print("  [OK] FixturePaletteEntry resource validated.")

	# 2. Validar FixturePalette con entries y filtrado por placement
	var style_lantern := FixtureStyleScript.new(
		&"test_lantern",
		FixtureStyleScript.Type.LANTERN,
		FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3.ZERO, true
	)
	var style_brazier := FixtureStyleScript.new(
		&"test_brazier",
		FixtureStyleScript.Type.BRAZIER,
		FixturePlacementModeScript.Mode.FLOOR
	)

	var entry_lantern := FixturePaletteEntryScript.new(style_lantern, 25.0)
	var entry_brazier := FixturePaletteEntryScript.new(style_brazier, 50.0)

	var palette := FixturePaletteScript.new(
		&"custom_palette",
		[entry, entry_lantern, entry_brazier]
	)

	var wall_entries = palette.get_entries_for_placement(FixturePlacementModeScript.Mode.WALL)
	assert(wall_entries.size() == 2, "FAIL: Should have 2 WALL entries")
	assert(wall_entries[0] == entry)
	assert(wall_entries[1] == entry_lantern)

	var floor_entries = palette.get_entries_for_placement(FixturePlacementModeScript.Mode.FLOOR)
	assert(floor_entries.size() == 1, "FAIL: Should have 1 FLOOR entry")
	assert(floor_entries[0] == entry_brazier)

	var hanging_entries = palette.get_entries_for_placement(FixturePlacementModeScript.Mode.HANGING)
	assert(hanging_entries.is_empty(), "FAIL: Should have 0 HANGING entries")

	print("  [OK] FixturePalette filter by placement validated.")
	print("[PASS] test_fixture_palette_entries completed successfully!")
	quit(0)
