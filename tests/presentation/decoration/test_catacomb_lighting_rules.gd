extends SceneTree

const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	print("--- Running test_catacomb_lighting_rules ---")

	# 1. Palette check
	var palette_resolver := _DecorationPaletteResolverScript.new()
	var dec_palette = palette_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, _RoomPurposeScript.Type.CATACOMB)

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

	# 2. Purpose Profile & Relationship Rules check
	var registry := _DecorationPurposeProfileRegistryScript.new()
	var profile = registry.get_profile_for_purpose(_RoomPurposeScript.Type.CATACOMB)
	assert(profile != null, "Profile must not be null")

	for r in profile.fixture_rules:
		assert(r.placement_mode != _FixturePlacementModeScript.Mode.HANGING, "No hanging fixtures in CATACOMB")

	if profile.relationship_profile != null:
		for rel in profile.relationship_profile.relations:
			assert(not rel.target_fixture_types.has(_FixtureStyleScript.Type.LANTERN), "No lantern relations in CATACOMB")
			assert(not rel.target_fixture_types.has(_FixtureStyleScript.Type.CANDLE_HOLDER), "No candle holder relations in CATACOMB")

	print("  [OK] CATACOMB purpose profile and relationship profile forbid hanging lamps, wall lanterns, and candle holders")

	print("[PASS] test_catacomb_lighting_rules completed successfully!")
	quit(0)
