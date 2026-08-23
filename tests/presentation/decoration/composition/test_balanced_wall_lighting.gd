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
	print("--- Running test_balanced_wall_lighting ---")

	var planner := _LightingPlannerScript.new()

	# Large room geometry 10x10 (inner floor cells 1 to 8)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 9):
		for y in range(1, 9):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 10):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 9))
	for y in range(1, 9):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(9, y))

	var geom = _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 8, 8),
		floor_cells,
		wall_cells,
		[]
	)

	var torch := _FixtureStyleScript.new(&"torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3.ZERO, true)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(torch, 100.0)
	])

	var occupancy_map = _OccupancyMapScript.new()

	# Rule: 4 wall torches
	var fixture_rules: Array = [
		_FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.WALL, 4, 4,
			_FixtureBudgetRuleScript.Affinity.PERIMETER,
			[_FixtureStyleScript.Type.TORCH], &"perimeter_torches"
		)
	]

	var result = planner.plan_room_lighting(10.0, null, palette, [], geom, occupancy_map, 42, 2.0, fixture_rules)

	var wall_sides: Dictionary = {}
	for dir in result:
		if dir.placement.mode == _FixturePlacementModeScript.Mode.WALL:
			wall_sides[dir.placement.wall_side] = true

	# We requested 4 torches in a 4-wall room. They MUST be distributed across 4 distinct wall sides!
	assert(wall_sides.size() == 4, "4 wall torches must be distributed across all 4 wall sides, got %d distinct sides" % wall_sides.size())
	print("  [OK] 4 wall torches distributed across %d distinct wall sides!" % wall_sides.size())

	print("[PASS] test_balanced_wall_lighting completed!")
	quit(0)
