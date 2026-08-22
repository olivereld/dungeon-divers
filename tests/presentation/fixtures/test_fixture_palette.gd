extends SceneTree

const FixturePaletteResolverScript = preload("res://src/presentation/fixtures/fixture_palette_resolver.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_palette ---")
	print("==================================================================")

	var resolver := FixturePaletteResolverScript.new()

	# 1. Crypt profile palette
	var prof_crypt := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.HEAVY_IRON
	)
	var pal_crypt = resolver.resolve_palette(prof_crypt)
	assert(pal_crypt != null, "FAIL: Crypt palette cannot be null")
	assert(pal_crypt.id == &"gothic_crypt_palette")
	assert(not pal_crypt.fixtures.is_empty(), "FAIL: Crypt fixtures list cannot be empty")
	var crypt_walls = pal_crypt.get_fixtures_by_placement(FixturePlacementModeScript.Mode.WALL)
	assert(not crypt_walls.is_empty())
	print("  [OK] Gothic Crypt fixture palette resolved (%d fixtures total)." % pal_crypt.fixtures.size())

	# 2. Temple profile palette
	var prof_temple := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
		ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH
	)
	var pal_temple = resolver.resolve_palette(prof_temple)
	assert(pal_temple != null, "FAIL: Temple palette cannot be null")
	assert(pal_temple.id == &"ceremonial_temple_palette")
	assert(not pal_temple.fixtures.is_empty())
	print("  [OK] Ceremonial Temple fixture palette resolved (%d fixtures total)." % pal_temple.fixtures.size())

	print("[PASS] test_fixture_palette completed successfully!")
	quit(0)
