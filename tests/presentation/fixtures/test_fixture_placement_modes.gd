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
	print("--- Running test_fixture_placement_modes ---")
	print("==================================================================")

	var resolver := FixturePaletteResolverScript.new()
	var prof_crypt := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.HEAVY_IRON
	)
	var pal = resolver.resolve_palette(prof_crypt)

	# 1. Torch → WALL
	var torch_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.WALL):
		if f.fixture_type == FixtureStyleScript.Type.TORCH:
			torch_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.WALL)
	assert(torch_found, "FAIL: Torch must have WALL placement")
	print("  [OK] Torch → WALL validated.")

	# 2. Wall Lantern → WALL
	var wall_lantern_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.WALL):
		if f.fixture_type == FixtureStyleScript.Type.LANTERN and f.is_wall_mounted:
			wall_lantern_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.WALL)
	assert(wall_lantern_found, "FAIL: Wall Lantern must have WALL placement")
	print("  [OK] Wall Lantern → WALL validated.")

	# 3. Hanging Lantern → HANGING
	var hanging_lantern_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.HANGING):
		if f.fixture_type == FixtureStyleScript.Type.LANTERN and not f.is_wall_mounted:
			hanging_lantern_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.HANGING)
	assert(hanging_lantern_found, "FAIL: Hanging Lantern must have HANGING placement")
	print("  [OK] Hanging Lantern → HANGING validated.")

	# 4. Brazier → FLOOR
	var brazier_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.FLOOR):
		if f.fixture_type == FixtureStyleScript.Type.BRAZIER:
			brazier_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.FLOOR)
	assert(brazier_found, "FAIL: Brazier must have FLOOR placement")
	print("  [OK] Brazier → FLOOR validated.")

	# 5. Candle Cluster → FLOOR
	var cluster_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.FLOOR):
		if f.fixture_type == FixtureStyleScript.Type.CANDLE_CLUSTER:
			cluster_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.FLOOR)
	assert(cluster_found, "FAIL: Candle Cluster must have FLOOR placement")
	print("  [OK] Candle Cluster → FLOOR validated.")

	# 6. Candle Holder → SURFACE
	var holder_found := false
	for f in pal.get_fixtures_by_placement(FixturePlacementModeScript.Mode.SURFACE):
		if f.fixture_type == FixtureStyleScript.Type.CANDLE_HOLDER:
			holder_found = true
			assert(f.placement_mode == FixturePlacementModeScript.Mode.SURFACE)
	assert(holder_found, "FAIL: Candle Holder must have SURFACE placement")
	print("  [OK] Candle Holder → SURFACE validated.")

	print("[PASS] test_fixture_placement_modes completed successfully!")
	quit(0)
