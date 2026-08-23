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
	print("--- Running test_relationship_min_max_diagnostics ---")

	var resolver := _PropFixtureRelationshipResolverScript.new()

	# Tiny room 3x3 with only 1 free neighbor cell around prop
	var floor_cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var wall_cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)
	]

	var geom = _PresentationRoomGeometryScript.new(1, Rect2i(1, 1, 2, 1), floor_cells, wall_cells, [])

	var candle := _FixtureStyleScript.new(&"candle", _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var palette := _FixturePaletteScript.new(&"test_palette", [_FixturePaletteEntryScript.new(candle, 100.0)])

	# Prop at (1, 1), only (2, 1) is free
	var occupancy_map = _OccupancyMapScript.new()
	var sarc = _PropDirectiveScript.new(
		&"sarcophagus", 1,
		_PropStyleScript.new(&"sarcophagus", _PropStyleScript.Type.SARCOPHAGUS),
		Vector3(2.0, 0.0, 2.0), 0.0, [Vector2i(1, 1)]
	)
	occupancy_map.add_footprint([Vector2i(1, 1)], &"sarcophagus", 0)

	# Relation requests MIN=2 candles, but room only has 1 cell!
	var rel := _PropFixtureRelationScript.new(
		&"sarcophagus",
		[_FixtureStyleScript.Type.CANDLE_CLUSTER],
		_PropFixtureRelationPlacementScript.Placement.NEAR,
		2, 2, &"sarc_candles_diag"
	)
	var profile := _PropFixtureRelationshipProfileScript.new(&"p_diag", [rel])

	var result = resolver.resolve_relationships_with_diagnostics([sarc], profile, palette, geom, occupancy_map, 42, 2.0)

	assert(result.directives.size() == 1, "Must place the 1 available candle")
	assert(result.diagnostics.size() == 1, "Must record 1 diagnostic entry")

	var diag = result.diagnostics[0]
	assert(diag["relation_id"] == &"sarc_candles_diag", "Relation ID must match")
	assert(diag["requested_min"] == 2, "Requested min must be 2")
	assert(diag["actual_count"] == 1, "Actual placed count must be 1")
	assert(diag["satisfied"] == false, "Satisfied must be false when actual < requested_min")
	assert(diag["failure_reason"] == &"INSUFFICIENT_VALID_ANCHORS", "Failure reason must accurately describe shortage of anchors")
	print("  [OK] Diagnostics accurately captured min_count shortage: requested=%d, placed=%d, satisfied=%s, reason=%s" % [
		diag["requested_min"], diag["actual_count"], str(diag["satisfied"]), str(diag["failure_reason"])
	])

	print("[PASS] test_relationship_min_max_diagnostics completed!")
	quit(0)
