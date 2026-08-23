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
	print("--- Running test_focal_lighting_companion ---")

	var planner := _LightingPlannerScript.new()

	# Room geometry 8x8 (inner floor cells from 1 to 6)
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
		_FixturePaletteEntryScript.new(brazier, 50.0),
		_FixturePaletteEntryScript.new(hanging, 50.0),
	])

	var occupancy_map = _OccupancyMapScript.new()

	# Sarcophagus primary prop occupying cells (3, 3) and (4, 3) in the center
	var primary_cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	occupancy_map.add_footprint(primary_cells, &"sarcophagus_primary", 0)

	# Declare rules:
	# 1. Focal companion hanging lantern directly above the sarcophagus
	# 2. Focal companion flanking braziers (1-2)
	# 3. Perimeter wall torches (1-3)
	var fixture_rules: Array = [
		_FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.HANGING, 1, 1,
			_FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION,
			[_FixtureStyleScript.Type.LANTERN], &"focal_lantern"
		),
		_FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.FLOOR, 2, 2,
			_FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION,
			[_FixtureStyleScript.Type.BRAZIER], &"focal_braziers"
		),
		_FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.WALL, 1, 3,
			_FixtureBudgetRuleScript.Affinity.PERIMETER,
			[_FixtureStyleScript.Type.TORCH], &"perimeter_torches"
		)
	]

	var result = planner.plan_room_lighting(8.0, null, palette, primary_cells, geom, occupancy_map, 42, 2.0, fixture_rules)

	var hanging_dirs: Array = []
	var floor_dirs: Array = []
	var wall_dirs: Array = []

	for dir in result:
		match dir.placement.mode:
			_FixturePlacementModeScript.Mode.HANGING:
				hanging_dirs.append(dir)
			_FixturePlacementModeScript.Mode.FLOOR:
				floor_dirs.append(dir)
			_FixturePlacementModeScript.Mode.WALL:
				wall_dirs.append(dir)

	# 1. Verify hanging lantern is centered directly above sarcophagus (centroid X = 4.0 * 2.0 = 8.0, Z = 3.5 * 2.0 = 7.0)
	assert(hanging_dirs.size() == 1, "Must place exactly 1 focal hanging lantern, got %d" % hanging_dirs.size())
	var h_dir = hanging_dirs[0]
	var expected_x: float = (3.5 + 0.5) * 2.0 # 8.0
	var expected_z: float = (3.0 + 0.5) * 2.0 # 7.0
	assert(is_equal_approx(h_dir.placement.position.x, expected_x), "Hanging lantern X should be centered at %.1f, got %.1f" % [expected_x, h_dir.placement.position.x])
	assert(is_equal_approx(h_dir.placement.position.z, expected_z), "Hanging lantern Z should be centered at %.1f, got %.1f" % [expected_z, h_dir.placement.position.z])
	print("  [OK] Focal hanging lantern positioned directly above primary prop centroid")

	# 2. Verify flanking braziers are near the primary prop (Manhattan distance 1 to 2)
	assert(floor_dirs.size() == 2, "Must place 2 focal flanking braziers, got %d" % floor_dirs.size())
	for fd in floor_dirs:
		var f_cell: Vector2i = fd.placement.cell
		var min_dist: int = 999
		for pc in primary_cells:
			var d: int = abs(f_cell.x - pc.x) + abs(f_cell.y - pc.y)
			min_dist = mini(min_dist, d)
		assert(min_dist >= 1 and min_dist <= 2, "Brazier at %s must flank primary prop at distance 1-2, got %d" % [str(f_cell), min_dist])
	print("  [OK] Focal braziers successfully placed flanking the primary prop")

	# 3. Verify perimeter torches
	assert(wall_dirs.size() >= 1, "Must place at least 1 perimeter wall torch")
	print("  [OK] Perimeter wall torches placed: %d" % wall_dirs.size())

	print("[PASS] test_focal_lighting_companion completed!")
	quit(0)
