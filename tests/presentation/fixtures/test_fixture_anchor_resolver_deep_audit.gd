extends SceneTree

const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	print("--- Running test_fixture_anchor_resolver_deep_audit ---")

	var resolver := _FixtureAnchorResolverScript.new()

	# Create a 6x6 room (floor cells from (1,1) to (6,6), center is (3.5, 3.5))
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
		[Vector2i(3, 0)] # Door on North wall
	)

	# 1. Test Hanging Anchors: First anchor must be near the room center (NOT in the (1,1) corner!)
	var hanging_anchors = resolver.find_hanging_anchors(geom, 2.0, 2.4)
	assert(not hanging_anchors.is_empty(), "Must find hanging anchors")
	var first_hanging = hanging_anchors[0]
	var dist_to_center = (Vector2(first_hanging.cell) - Vector2(3.5, 3.5)).length()
	assert(dist_to_center < 1.5, "First ambient hanging anchor must be near room center (got cell %s, dist %.2f)" % [str(first_hanging.cell), dist_to_center])
	print("  [OK] Ambient hanging anchors prioritize room center (cell: %s)" % str(first_hanging.cell))

	# 2. Test Wall Anchors: Must have valid wall anchors on all 4 walls
	var wall_anchors = resolver.find_wall_anchors(geom, 2.0)
	var sides_found: Dictionary = {}
	for wa in wall_anchors:
		sides_found[wa.wall_side] = true
	assert(sides_found.size() == 4, "Must find wall anchors on all 4 sides, got %d" % sides_found.size())
	print("  [OK] Wall anchors found on all 4 perimeter sides")

	# 3. Test Floor Anchors: Must not include door position (3, 0) or direct forward entrance step (3, 1)
	var floor_anchors = resolver.find_floor_anchors(geom, 2.0)
	for fa in floor_anchors:
		assert(fa.cell != Vector2i(3, 0) and fa.cell != Vector2i(3, 1), "Floor anchor must not block doorway at %s" % str(fa.cell))
	print("  [OK] Floor anchors respect doorway clearance without wiping out room")

	# 4. Test Focal Companion Anchors for Sarcophagus at (3,3) & (4,3)
	var primary_cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	var focal_hanging = resolver.find_focal_companion_anchors(primary_cells, geom, _FixturePlacementModeScript.Mode.HANGING, 2.0)
	assert(focal_hanging.size() == 1, "Must find 1 focal hanging anchor")
	assert(is_equal_approx(focal_hanging[0].position.x, 8.0), "Centroid X should be 8.0")
	assert(is_equal_approx(focal_hanging[0].position.z, 7.0), "Centroid Z should be 7.0")
	print("  [OK] Focal hanging anchor perfectly centered over multi-tile focal prop")

	var focal_floor = resolver.find_focal_companion_anchors(primary_cells, geom, _FixturePlacementModeScript.Mode.FLOOR, 2.0)
	assert(focal_floor.size() >= 4, "Must find flanking floor anchors around primary prop")
	print("  [OK] Focal flanking floor anchors found: %d candidates" % focal_floor.size())

	print("[PASS] test_fixture_anchor_resolver_deep_audit completed!")
	quit(0)
