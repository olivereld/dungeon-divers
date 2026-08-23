extends SceneTree

const _LightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _OccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("--- Running test_fixture_footprint_validation ---")

	var planner := _LightingPlannerScript.new()

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

	# Create a 2x2 Grand Brazier with footprint
	var grand_brazier := _FixtureStyleScript.new(
		&"grand_brazier_2x2",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0,
		Vector3.ZERO,
		false,
		0,
		true,
		Color(1.0, 0.65, 0.28, 1.0),
		2.0,
		8.0,
		null,
		_PropFootprintScript.new(Vector2i(2, 2))
	)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(grand_brazier, 100.0)
	])

	# Scenario 1: Partial obstacle (e.g. sarcophagus at (3,3))
	# A 2x2 footprint centered at (3,3) would occupy (3,3), (4,3), (3,4), (4,4) -> must be rejected because (3,3) is occupied!
	var occupancy_map = _OccupancyMapScript.new()
	occupancy_map.add_footprint([Vector2i(3, 3)], &"obstacle_prop", 0)

	var fixture_rules: Array = [
		_FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.FLOOR, 1, 1,
			_FixtureBudgetRuleScript.Affinity.FREE,
			[_FixtureStyleScript.Type.BRAZIER], &"grand_brazier_rule"
		)
	]

	var result = planner.plan_room_lighting(6.0, null, palette, [], geom, occupancy_map, 42, 2.0, fixture_rules)

	assert(result.size() == 1, "Must find a valid 2x2 free space for the grand brazier")
	var placed_brazier = result[0]
	var origin_cell: Vector2i = placed_brazier.placement.cell

	# Verify none of the 4 footprint cells collide with the obstacle at (3, 3)
	var occupied_by_brazier: Array[Vector2i] = grand_brazier.footprint.get_occupied_cells(origin_cell, placed_brazier.placement.rotation_y)
	assert(not occupied_by_brazier.has(Vector2i(3, 3)), "2x2 brazier footprint must NOT overlap obstacle at (3,3)")
	print("  [OK] 2x2 Grand Brazier footprint avoided collision with obstacle cell")

	# Verify that occupancy map now contains all 4 footprint cells
	for cell in occupied_by_brazier:
		assert(occupancy_map.is_cell_occupied(cell), "Occupancy map must contain brazier cell %s" % str(cell))
	print("  [OK] All 4 cells of 2x2 footprint successfully registered in occupancy map")

	print("[PASS] test_fixture_footprint_validation completed!")
	quit(0)
