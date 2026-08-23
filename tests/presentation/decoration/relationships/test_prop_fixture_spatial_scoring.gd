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
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _OccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("--- Running test_prop_fixture_spatial_scoring ---")

	var resolver := _PropFixtureRelationshipResolverScript.new()

	# 7x7 room (floor 1..5)
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

	var geom = _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 5, 5),
		floor_cells,
		wall_cells,
		[]
	)

	var candle := _FixtureStyleScript.new(&"candle", _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var palette := _FixturePaletteScript.new(&"test_palette", [_FixturePaletteEntryScript.new(candle, 100.0)])

	# Test 1: Sarcophagus facing NORTH (rot = 0 deg) -> Request RIGHT placement
	var occupancy_map_north = _OccupancyMapScript.new()
	var sarc_north = _PropDirectiveScript.new(
		&"sarcophagus", 1,
		_PropStyleScript.new(&"sarcophagus", _PropStyleScript.Type.SARCOPHAGUS),
		Vector3(6.0, 0.0, 6.0), 0.0, [Vector2i(3, 3)]
	)
	occupancy_map_north.add_footprint([Vector2i(3, 3)], &"sarcophagus", 0)

	var rel_right := _PropFixtureRelationScript.new(
		&"sarcophagus", [_FixtureStyleScript.Type.CANDLE_CLUSTER],
		_PropFixtureRelationPlacementScript.Placement.RIGHT, 1, 1, &"sarc_right", 1.0, 2.0
	)
	var profile_north := _PropFixtureRelationshipProfileScript.new(&"p_north", [rel_right])

	var res_north = resolver.resolve_relationships([sarc_north], profile_north, palette, geom, occupancy_map_north, 42, 2.0)
	assert(res_north.size() == 1, "Must place 1 right-flanking candle")
	var north_right_cell: Vector2i = res_north[0].placement.cell
	# Facing north (rot=0), right is +X -> cell should be (4, 3)
	assert(north_right_cell.x > 3, "Right of north-facing prop must be +X (east), got %s" % str(north_right_cell))
	print("  [OK] Directional scoring for NORTH rotation correctly picked RIGHT candidate: %s" % str(north_right_cell))

	# Test 2: Sarcophagus facing EAST (rot = 90 deg) -> Request RIGHT placement
	var occupancy_map_east = _OccupancyMapScript.new()
	var sarc_east = _PropDirectiveScript.new(
		&"sarcophagus", 1,
		_PropStyleScript.new(&"sarcophagus", _PropStyleScript.Type.SARCOPHAGUS),
		Vector3(6.0, 0.0, 6.0), 90.0, [Vector2i(3, 3)] # 90 deg rotation
	)
	occupancy_map_east.add_footprint([Vector2i(3, 3)], &"sarcophagus", 0)

	var profile_east := _PropFixtureRelationshipProfileScript.new(&"p_east", [rel_right])
	var res_east = resolver.resolve_relationships([sarc_east], profile_east, palette, geom, occupancy_map_east, 42, 2.0)
	assert(res_east.size() == 1, "Must place 1 right-flanking candle for east-facing prop")
	var east_right_cell: Vector2i = res_east[0].placement.cell
	# Facing east (rot=90 deg), right is +Y -> cell should be (3, 4)
	assert(east_right_cell.y > 3, "Right of east-facing prop must be +Y (south), got %s" % str(east_right_cell))
	print("  [OK] Directional scoring for EAST (90 deg) rotation correctly picked RIGHT candidate: %s" % str(east_right_cell))

	print("[PASS] test_prop_fixture_spatial_scoring completed!")
	quit(0)
