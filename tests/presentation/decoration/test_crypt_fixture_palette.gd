extends SceneTree

const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_crypt_fixture_palette ---")
	print("==================================================================")

	var dec_resolver := DecorationPaletteResolverScript.new()
	var prof := ArchitecturalPresentationProfileScript.new()

	# 1. Crypt Tomb Palette
	var dec_pal_tomb = dec_resolver.resolve_palette_by_id(
		&"necropolis",
		&"tomb",
		prof
	)
	assert(dec_pal_tomb != null, "FAIL: DecorationPalette cannot be null")
	assert(dec_pal_tomb.fixtures != null, "FAIL: Fixtures palette cannot be null")

	var fix_tomb = dec_pal_tomb.fixtures
	var wall_entries = fix_tomb.get_entries_for_placement(FixturePlacementModeScript.Mode.WALL)
	var floor_entries = fix_tomb.get_entries_for_placement(FixturePlacementModeScript.Mode.FLOOR)
	var surface_entries = fix_tomb.get_entries_for_placement(FixturePlacementModeScript.Mode.SURFACE)
	var hanging_entries = fix_tomb.get_entries_for_placement(FixturePlacementModeScript.Mode.HANGING)

	assert(not wall_entries.is_empty(), "FAIL: Tomb must have wall fixtures")
	assert(not floor_entries.is_empty(), "FAIL: Tomb must have floor fixtures")
	assert(not surface_entries.is_empty(), "FAIL: Tomb must have surface fixtures")
	assert(not hanging_entries.is_empty(), "FAIL: Tomb must have hanging fixtures")

	# Verificar que en Tomb los faroles tienen mayor peso que las antorchas
	var torch_w: float = 0.0
	var lantern_w: float = 0.0
	for e in wall_entries:
		if e.style.fixture_type == FixtureStyleScript.Type.TORCH:
			torch_w = e.weight
		elif e.style.fixture_type == FixtureStyleScript.Type.LANTERN:
			lantern_w = e.weight

	assert(lantern_w > torch_w, "FAIL: In Crypt Tomb, Wall Lantern weight (%.1f) should exceed Torch weight (%.1f)" % [lantern_w, torch_w])
	print("  [OK] Crypt Tomb palette weights validated (Lantern: %.1f > Torch: %.1f)." % [lantern_w, torch_w])

	# 2. Crypt Entrance Palette
	var dec_pal_ante = dec_resolver.resolve_palette_by_id(
		&"necropolis",
		&"entrance",
		prof
	)
	var fix_ante = dec_pal_ante.fixtures
	var ante_torch_w: float = 0.0
	var ante_lantern_w: float = 0.0
	for e in fix_ante.get_entries_for_placement(FixturePlacementModeScript.Mode.WALL):
		if e.style.fixture_type == FixtureStyleScript.Type.TORCH:
			ante_torch_w = e.weight
		elif e.style.fixture_type == FixtureStyleScript.Type.LANTERN:
			ante_lantern_w = e.weight

	assert(ante_torch_w > ante_lantern_w, "FAIL: In Crypt Entrance, Torch weight (%.1f) should exceed Lantern weight (%.1f)" % [ante_torch_w, ante_lantern_w])
	print("  [OK] Crypt Entrance palette weights validated (Torch: %.1f > Lantern: %.1f)." % [ante_torch_w, ante_lantern_w])

	print("[PASS] test_crypt_fixture_palette completed successfully!")
	quit(0)
