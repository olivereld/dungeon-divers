extends SceneTree

const FixturePaletteResolverScript = preload("res://src/presentation/fixtures/fixture_palette_resolver.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_taxonomy ---")
	print("==================================================================")

	var resolver := FixturePaletteResolverScript.new()
	var prof_crypt := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.HEAVY_IRON
	)
	var pal_crypt = resolver.resolve_palette(prof_crypt)

	# 1. Torch -> WALL
	var wall_fixtures = pal_crypt.get_fixtures_by_placement(FixturePlacementModeScript.Mode.WALL)
	var torch_found: bool = false
	var wall_lantern_found: bool = false
	for f in wall_fixtures:
		if f.fixture_type == FixtureStyleScript.Type.TORCH:
			torch_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.WALL)
		if f.fixture_type == FixtureStyleScript.Type.LANTERN and f.is_wall_mounted:
			wall_lantern_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.WALL)
	assert(torch_found, "FAIL: Torch must have WALL placement")
	assert(wall_lantern_found, "FAIL: WallLantern must have WALL placement")
	print("  [OK] Torch -> WALL and WallLantern -> WALL verified.")

	# 2. HangingLantern -> HANGING
	var hanging_fixtures = pal_crypt.get_fixtures_by_placement(FixturePlacementModeScript.Mode.HANGING)
	var hanging_lantern_found: bool = false
	for f in hanging_fixtures:
		if f.fixture_type == FixtureStyleScript.Type.LANTERN and not f.is_wall_mounted:
			hanging_lantern_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.HANGING)
	assert(hanging_lantern_found, "FAIL: HangingLantern must have HANGING placement")
	print("  [OK] HangingLantern -> HANGING verified.")

	# 3. Brazier -> FLOOR & CandleCluster -> FLOOR
	var floor_fixtures = pal_crypt.get_fixtures_by_placement(FixturePlacementModeScript.Mode.FLOOR)
	var brazier_found: bool = false
	var candle_cluster_found: bool = false
	for f in floor_fixtures:
		if f.fixture_type == FixtureStyleScript.Type.BRAZIER:
			brazier_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.FLOOR)
		if f.fixture_type == FixtureStyleScript.Type.CANDLE_CLUSTER:
			candle_cluster_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.FLOOR)
	assert(brazier_found, "FAIL: Brazier must have FLOOR placement")
	assert(candle_cluster_found, "FAIL: CandleCluster must have FLOOR placement")
	print("  [OK] Brazier -> FLOOR and CandleCluster -> FLOOR verified.")

	# 4. CandleHolder -> SURFACE
	var surface_fixtures = pal_crypt.get_fixtures_by_placement(FixturePlacementModeScript.Mode.SURFACE)
	var candle_holder_found: bool = false
	for f in surface_fixtures:
		if f.fixture_type == FixtureStyleScript.Type.CANDLE_HOLDER:
			candle_holder_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.SURFACE)
	assert(candle_holder_found, "FAIL: CandleHolder must have SURFACE placement")
	print("  [OK] CandleHolder -> SURFACE verified.")

	print("[PASS] test_fixture_taxonomy completed successfully!")
	quit(0)
