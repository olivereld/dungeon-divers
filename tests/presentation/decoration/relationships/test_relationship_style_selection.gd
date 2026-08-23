extends SceneTree

const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")
const _PropFixtureRelationshipProfileScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_profile.gd")
const _PropFixtureRelationshipResolverScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_resolver.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _OccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("--- Running test_relationship_style_selection ---")

	var resolver := _PropFixtureRelationshipResolverScript.new()

	var floor_cells: Array[Vector2i] = []
	for x in range(1, 6):
		for y in range(1, 6):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 7):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 6))
	for y in range(1, 6):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(6, y))

	var geom = _PresentationRoomGeometryScript.new(1, Rect2i(1, 1, 5, 5), floor_cells, wall_cells, [])

	# Multiple compatible candle styles in palette with distinct IDs & weights
	var small_candle := _FixtureStyleScript.new(&"candle_small", _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var large_candle := _FixtureStyleScript.new(&"candle_large", _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var ritual_candle := _FixtureStyleScript.new(&"candle_ritual", _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixturePlacementModeScript.Mode.FLOOR, 1.0)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(small_candle, 10.0),
		_FixturePaletteEntryScript.new(large_candle, 50.0),
		_FixturePaletteEntryScript.new(ritual_candle, 100.0) # Highest weight
	])

	var occupancy_map = _OccupancyMapScript.new()
	var sarc = _PropDirectiveScript.new(
		&"sarcophagus", 1,
		_PropStyleScript.new(&"sarcophagus", _PropStyleScript.Type.SARCOPHAGUS),
		Vector3(6.0, 0.0, 6.0), 0.0, [Vector2i(3, 3)]
	)
	occupancy_map.add_footprint([Vector2i(3, 3)], &"sarcophagus", 0)

	var rel := _PropFixtureRelationScript.new(
		&"sarcophagus",
		[_FixtureStyleScript.Type.CANDLE_CLUSTER],
		_PropFixtureRelationPlacementScript.Placement.NEAR,
		2, 2, &"sarc_candles"
	)
	var profile := _PropFixtureRelationshipProfileScript.new(&"p", [rel])

	var result = resolver.resolve_relationships_with_diagnostics([sarc], profile, palette, geom, occupancy_map, 42, 2.0)

	assert(result.directives.size() == 2, "Must resolve 2 relational candles")
	assert(result.is_all_satisfied(), "All requested relationships must be satisfied")

	# Check that highest weighted ritual candle candidate was favored
	var placed_styles: Array[StringName] = []
	for dir in result.directives:
		placed_styles.append(dir.style.id)
		assert(dir.source_type == 1, "Source type must be PROP_RELATION")
		assert(dir.source_prop_id == &"sarcophagus", "Source prop ID must be sarcophagus")
		assert(dir.relation_id == &"sarc_candles", "Relation ID must be sarc_candles")

	assert(placed_styles.has(&"candle_ritual"), "Candidate generation across all styles must allow ritual candle to be selected")
	print("  [OK] Evaluated all compatible styles from palette and selected top-scored variants (%s)" % str(placed_styles))

	print("[PASS] test_relationship_style_selection completed!")
	quit(0)
