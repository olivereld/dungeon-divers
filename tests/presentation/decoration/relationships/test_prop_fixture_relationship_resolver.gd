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
	print("--- Running test_prop_fixture_relationship_resolver ---")

	var resolver := _PropFixtureRelationshipResolverScript.new()

	# 6x6 room (floor 1..6)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 8):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 7))
	for y in range(1, 7):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(7, y))

	var geom = _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 6, 6),
		floor_cells,
		wall_cells,
		[]
	)

	var candle := _FixtureStyleScript.new(
		&"crypt_candle",
		_FixtureStyleScript.Type.CANDLE_CLUSTER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0
	)
	var lantern := _FixtureStyleScript.new(
		&"hanging_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0
	)
	var brazier := _FixtureStyleScript.new(
		&"brazier",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0
	)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(candle, 100.0),
		_FixturePaletteEntryScript.new(lantern, 100.0),
		_FixturePaletteEntryScript.new(brazier, 100.0)
	])

	var occupancy_map = _OccupancyMapScript.new()

	# Placed Sarcophagus at (3, 3) footprint 2x1
	var sarc_style := _PropStyleScript.new(&"sarcophagus_ornate", _PropStyleScript.Type.SARCOPHAGUS, 0, 0, _PropFootprintScript.new(Vector2i(2, 1)))
	var sarc_directive := _PropDirectiveScript.new(sarc_style.id, 1, sarc_style, Vector3(7.0, 0.0, 7.0), 0.0, [Vector2i(3, 3), Vector2i(4, 3)])
	occupancy_map.add_footprint([Vector2i(3, 3), Vector2i(4, 3)], sarc_style.id, 0)

	# Placed Bench at (1, 1)
	var bench_style := _PropStyleScript.new(&"wood_bench", _PropStyleScript.Type.BENCH, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)))
	var bench_directive := _PropDirectiveScript.new(bench_style.id, 1, bench_style, Vector3(3.0, 0.0, 3.0), 0.0, [Vector2i(1, 1)])
	occupancy_map.add_footprint([Vector2i(1, 1)], bench_style.id, 0)

	var placed_props: Array = [sarc_directive, bench_directive]

	# Declare Relations in Profile:
	# 1. Sarcophagus -> Hanging Lantern (ABOVE, count=1)
	# 2. Sarcophagus -> Candle (NEAR, count=2)
	# 3. Bench -> Forbidden fixtures (min=0, max=0)
	var rel_profile := _PropFixtureRelationshipProfileScript.new(&"crypt_profile", [
		_PropFixtureRelationScript.new(
			&"sarcophagus_ornate",
			[_FixtureStyleScript.Type.LANTERN],
			_PropFixtureRelationPlacementScript.Placement.ABOVE,
			1, 1, &"sarc_hanging"
		),
		_PropFixtureRelationScript.new(
			&"sarcophagus_ornate",
			[_FixtureStyleScript.Type.CANDLE_CLUSTER],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			2, 2, &"sarc_candles", 1.0, 2.0
		),
		_PropFixtureRelationScript.new(
			&"wood_bench",
			[],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 0, &"bench_no_fixtures", 1.0, 2.0, 1.0,
			[_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.CANDLE_CLUSTER]
		)
	])

	var result = resolver.resolve_relationships(
		placed_props,
		rel_profile,
		palette,
		geom,
		occupancy_map,
		42,
		2.0
	)

	var hanging_results: Array = []
	var candle_results: Array = []

	for dir in result:
		if dir.placement.mode == _FixturePlacementModeScript.Mode.HANGING:
			hanging_results.append(dir)
		elif dir.placement.mode == _FixturePlacementModeScript.Mode.FLOOR:
			candle_results.append(dir)

	# 1. Verify Hanging Lantern directly above sarcophagus (centroid X = 4.0 * 2.0 = 8.0, Z = 3.5 * 2.0 = 7.0)
	assert(hanging_results.size() == 1, "Must generate 1 hanging lantern above sarcophagus, got %d" % hanging_results.size())
	assert(is_equal_approx(hanging_results[0].placement.position.x, 8.0), "Centroid X must be 8.0")
	assert(is_equal_approx(hanging_results[0].placement.position.z, 7.0), "Centroid Z must be 7.0")
	print("  [OK] Relational hanging lantern perfectly centered above sarcophagus")

	# 2. Verify 2 Candles placed near sarcophagus and registered in occupancy
	assert(candle_results.size() == 2, "Must generate 2 candles flanking sarcophagus, got %d" % candle_results.size())
	for c in candle_results:
		var c_cell: Vector2i = c.placement.cell
		assert(c_cell != Vector2i(3, 3) and c_cell != Vector2i(4, 3), "Candle must not occupy sarcophagus footprint")
		assert(occupancy_map.is_cell_occupied(c_cell), "Candle cell %s must be registered in occupancy map" % str(c_cell))
	print("  [OK] Relational candles placed and registered without colliding with sarcophagus")

	# 3. Verify Bench produced NO fixtures
	assert(result.size() == 3, "Total fixtures must be 3 (1 hanging + 2 candles), got %d" % result.size())
	print("  [OK] Bench produced 0 fixtures (forbidden rule respected)")

	print("[PASS] test_prop_fixture_relationship_resolver completed!")
	quit(0)
