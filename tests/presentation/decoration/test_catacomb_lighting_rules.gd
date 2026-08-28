extends SceneTree

const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")

func _init() -> void:
	print("--- Running test_catacomb_lighting_rules ---")

	# 1. Palette check
	var palette_resolver := _DecorationPaletteResolverScript.new()
	var dec_palette = palette_resolver.resolve_palette_by_id(&"necropolis", &"catacomb")

	assert(dec_palette != null and dec_palette.fixtures != null, "Fixture palette must not be null")
	var palette = dec_palette.fixtures
	var allowed_types: Array[int] = [
		_FixtureStyleScript.Type.TORCH,
		_FixtureStyleScript.Type.BRAZIER,
		_FixtureStyleScript.Type.CANDLE_CLUSTER
	]

	for entry in palette.entries:
		var f_type: int = entry.style.fixture_type
		assert(allowed_types.has(f_type), "CATACOMB palette can only have Torch, Brazier, or CandleCluster. Found: %d (%s)" % [
			f_type, str(entry.style.id)
		])
		assert(f_type != _FixtureStyleScript.Type.LANTERN, "No lanterns allowed in CATACOMB")
		assert(f_type != _FixtureStyleScript.Type.CANDLE_HOLDER, "No candle holders allowed in CATACOMB")

	print("  [OK] CATACOMB fixture palette contains exclusively Torches, Braziers, and Candle Clusters")

	# 2. JSON Profile Lighting check
	var loader := _ProfileLoaderScript.new()
	var profile = loader.load_room("catacomb.json")
	assert(profile != null, "Profile must not be null")
	assert(profile.lighting != null, "Lighting config must not be null")
	assert(profile.lighting.hanging.max_count == 0, "No hanging fixtures in CATACOMB")

	print("  [OK] CATACOMB JSON room profile forbids hanging lamps")
	print("[PASS] test_catacomb_lighting_rules completed successfully!")
	quit(0)
