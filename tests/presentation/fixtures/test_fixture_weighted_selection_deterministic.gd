extends SceneTree

const FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_weighted_selection_deterministic ---")
	print("==================================================================")

	var s_torch := FixtureStyleScript.new(&"torch", FixtureStyleScript.Type.TORCH, FixturePlacementModeScript.Mode.WALL)
	var s_lantern := FixtureStyleScript.new(&"lantern", FixtureStyleScript.Type.LANTERN, FixturePlacementModeScript.Mode.WALL)
	var s_unused := FixtureStyleScript.new(&"unused", FixtureStyleScript.Type.TORCH, FixturePlacementModeScript.Mode.WALL)

	var e_torch := FixturePaletteEntryScript.new(s_torch, 80.0)
	var e_lantern := FixturePaletteEntryScript.new(s_lantern, 20.0)
	var e_unused := FixturePaletteEntryScript.new(s_unused, 0.0) # Weight 0 -> nunca seleccionado

	var palette := FixturePaletteScript.new(&"weighted_palette", [e_torch, e_lantern, e_unused])

	# 1. Mismo seed -> Mismo resultado exacto
	for test_seed in [12345, 99999, 442211, 876543]:
		var res1 = palette.select_weighted(FixturePlacementModeScript.Mode.WALL, test_seed)
		var res2 = palette.select_weighted(FixturePlacementModeScript.Mode.WALL, test_seed)
		assert(res1 == res2, "FAIL: Weighted selection is not deterministic for seed %d" % test_seed)

	# 2. Weight 0 nunca es seleccionado y pesos mayores tienen mayor frecuencia
	var torch_count: int = 0
	var lantern_count: int = 0
	var unused_count: int = 0
	var iterations: int = 1000

	for i in range(iterations):
		var selected = palette.select_weighted(FixturePlacementModeScript.Mode.WALL, i * 37 + 11)
		if selected == s_torch:
			torch_count += 1
		elif selected == s_lantern:
			lantern_count += 1
		elif selected == s_unused:
			unused_count += 1

	assert(unused_count == 0, "FAIL: 0-weight entry was selected!")
	assert(torch_count > lantern_count, "FAIL: 80-weight torch should be selected more often than 20-weight lantern")
	print("  [OK] Weighted selection stats (1000 runs): Torch=%d (80%% expected), Lantern=%d (20%% expected), Unused=%d (0 expected)" % [
		torch_count, lantern_count, unused_count
	])

	print("[PASS] test_fixture_weighted_selection_deterministic completed successfully!")
	quit(0)
