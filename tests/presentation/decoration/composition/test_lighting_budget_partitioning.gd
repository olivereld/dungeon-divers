extends SceneTree

const _LightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _OccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("--- Running test_lighting_budget_partitioning ---")

	var planner := _LightingPlannerScript.new()

	# Build a room geometry (8x8)
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

	# Create fixtures: wall torch (cost=1.0), brazier (cost=2.0), hanging lantern (cost=1.5)
	var torch := _FixtureStyleScript.new(&"torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3.ZERO, true)
	var brazier := _FixtureStyleScript.new(&"brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR, 1.0)
	var hanging := _FixtureStyleScript.new(&"hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING, 1.0)

	var palette := _FixturePaletteScript.new(&"test_palette", [
		_FixturePaletteEntryScript.new(torch, 80.0),
		_FixturePaletteEntryScript.new(brazier, 70.0),
		_FixturePaletteEntryScript.new(hanging, 50.0),
	])

	var occupancy_map = _OccupancyMapScript.new()

	# Budget = 10.0
	# With partitioning, hanging and floor must both get at least 1 fixture
	var result = planner.plan_room_lighting(10.0, null, palette, [], geom, occupancy_map, 42, 2.0)

	# Count fixtures per mode
	var wall_count: int = 0
	var floor_count: int = 0
	var hanging_count: int = 0
	for dir in result:
		match dir.placement.mode:
			_FixturePlacementModeScript.Mode.WALL:
				wall_count += 1
			_FixturePlacementModeScript.Mode.FLOOR:
				floor_count += 1
			_FixturePlacementModeScript.Mode.HANGING:
				hanging_count += 1

	assert(wall_count >= 1, "WALL must have fixtures, got %d" % wall_count)
	print("  [OK] WALL fixtures placed: %d" % wall_count)
	assert(hanging_count >= 1, "HANGING must get its own budget share, got %d" % hanging_count)
	print("  [OK] HANGING fixtures placed: %d" % hanging_count)
	assert(floor_count >= 1, "FLOOR must get its own budget share, got %d" % floor_count)
	print("  [OK] FLOOR fixtures placed: %d" % floor_count)

	print("[PASS] test_lighting_budget_partitioning completed!")
	quit(0)
