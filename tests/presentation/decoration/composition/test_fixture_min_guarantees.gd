extends SceneTree

const _LightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _OccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("--- Running test_fixture_min_guarantees ---")

	var planner := _LightingPlannerScript.new()

	# Room geometry 8x8
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

	var torch := _FixtureStyleScript.new(&"torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3.ZERO, true)
	var brazier := _FixtureStyleScript.new(&"brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var hanging := _FixtureStyleScript.new(&"hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING, 1.0)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(torch, 90.0),
		_FixturePaletteEntryScript.new(brazier, 40.0),
		_FixturePaletteEntryScript.new(hanging, 30.0),
	])

	var occupancy_map = _OccupancyMapScript.new()

	# Define fixture rules: wall 1-3, hanging 1-1, floor 0-1
	var fixture_rules: Array = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 3),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.HANGING, 1, 1),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.FLOOR, 0, 1),
	]

	# Budget of 6.0 — tight, but fixture_rules guarantee hanging min=1
	var result = planner.plan_room_lighting(6.0, null, palette, [], geom, occupancy_map, 42, 2.0, fixture_rules)

	var wall_count: int = 0
	var hanging_count: int = 0
	var floor_count: int = 0
	for dir in result:
		match dir.placement.mode:
			_FixturePlacementModeScript.Mode.WALL:
				wall_count += 1
			_FixturePlacementModeScript.Mode.HANGING:
				hanging_count += 1
			_FixturePlacementModeScript.Mode.FLOOR:
				floor_count += 1

	assert(wall_count >= 1, "WALL min_count=1 must be satisfied, got %d" % wall_count)
	print("  [OK] WALL min guarantee met: %d" % wall_count)
	assert(hanging_count >= 1, "HANGING min_count=1 must be satisfied, got %d" % hanging_count)
	print("  [OK] HANGING min guarantee met: %d" % hanging_count)
	assert(wall_count <= 3, "WALL max_count=3 must be respected, got %d" % wall_count)
	print("  [OK] WALL max respected: %d" % wall_count)
	assert(hanging_count <= 1, "HANGING max_count=1 must be respected, got %d" % hanging_count)
	print("  [OK] HANGING max respected: %d" % hanging_count)

	print("[PASS] test_fixture_min_guarantees completed!")
	quit(0)
