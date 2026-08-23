extends SceneTree

const _DecorationLightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lighting_planner_modes ---")
	print("==================================================================")

	_test_hanging_fixtures_placed()
	_test_floor_fixtures_allow_multiple()

	print("[OK] All lighting planner mode tests passed!")
	quit(0)

func _test_hanging_fixtures_placed() -> void:
	var planner = _DecorationLightingPlannerScript.new()
	var palette = _make_palette_with_hanging()
	var geom = _make_test_room_geom()
	var occ = _DecorationOccupancyMapScript.new()

	var directives = planner.plan_room_lighting(10.0, null, palette, [], geom, occ, 42, 2.0)

	var hanging_count: int = 0
	for d in directives:
		if d.placement != null and d.placement.mode == _FixturePlacementModeScript.Mode.HANGING:
			hanging_count += 1
	assert(hanging_count > 0, "FAIL: Must place at least 1 HANGING fixture when palette has them and budget allows")
	print("  [OK] HANGING fixtures placed: %d" % hanging_count)

func _test_floor_fixtures_allow_multiple() -> void:
	var planner = _DecorationLightingPlannerScript.new()
	var palette = _make_palette_floor_only()
	var geom = _make_test_room_geom()
	var occ = _DecorationOccupancyMapScript.new()

	# High budget should allow more than 1 floor fixture
	var directives = planner.plan_room_lighting(20.0, null, palette, [], geom, occ, 42, 2.0)

	var floor_count: int = 0
	for d in directives:
		if d.placement != null and d.placement.mode == _FixturePlacementModeScript.Mode.FLOOR:
			floor_count += 1
	assert(floor_count >= 2, "FAIL: With budget=20 and spacing, should place multiple floor fixtures (got %d)" % floor_count)
	print("  [OK] FLOOR fixtures allow multiple: %d placed" % floor_count)

func _make_palette_with_hanging() -> _FixturePaletteScript:
	var hanging = _FixtureStyleScript.new(
		&"test_hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.8, 0.4, 1.0), 1.5, 7.0
	)
	var torch = _FixtureStyleScript.new(
		&"test_wall_torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 2.0, 0.0), false, 0,
		true, Color(1.0, 0.6, 0.2, 1.0), 1.4, 6.5
	)
	var entries: Array[_FixturePaletteEntryScript] = [
		_FixturePaletteEntryScript.new(torch, 50.0),
		_FixturePaletteEntryScript.new(hanging, 80.0)
	]
	return _FixturePaletteScript.new(&"test_hanging_palette", entries, 3, 0.8, 4, 0.5)

func _make_palette_floor_only() -> _FixturePaletteScript:
	var brazier = _FixtureStyleScript.new(
		&"test_brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, 1,
		true, Color(1.0, 0.5, 0.2, 1.0), 2.0, 8.0
	)
	var entries: Array[_FixturePaletteEntryScript] = [
		_FixturePaletteEntryScript.new(brazier, 90.0)
	]
	return _FixturePaletteScript.new(&"test_floor_palette", entries, 3, 0.8, 3, 0.9)

func _make_test_room_geom():
	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	for x in range(1, 9):
		for y in range(1, 9):
			floor_cells.append(Vector2i(x, y))
	for x in range(0, 10):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 9))
	for y in range(1, 9):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(9, y))

	return _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 8, 8),
		floor_cells,
		wall_cells,
		[]
	)
