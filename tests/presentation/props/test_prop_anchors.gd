extends SceneTree

const PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_anchors ---")
	print("==================================================================")

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1

	# Construir una sala 6x6 (de (2,2) a (7,7))
	for x in range(2, 8):
		for y in range(2, 8):
			r_geom.floor_cells.append(Vector2i(x, y))

	var resolver := PropAnchorResolverScript.new()

	# 1. Floor Anchors
	var floor_anchors = resolver.find_floor_anchors(r_geom, 2.0)
	assert(floor_anchors.size() == 36, "FAIL: Expected 36 floor anchors, got %d" % floor_anchors.size())
	assert(floor_anchors[0].mode == PropPlacementModeScript.Mode.FLOOR)
	print("  [OK] Floor anchors discovered: %d" % floor_anchors.size())

	# 2. Wall Anchors
	var wall_anchors = resolver.find_wall_anchors(r_geom, 2.0)
	assert(not wall_anchors.is_empty(), "FAIL: Expected perimeter wall anchors")
	assert(wall_anchors[0].mode == PropPlacementModeScript.Mode.WALL)
	print("  [OK] Wall anchors discovered: %d" % wall_anchors.size())

	# 3. Center Anchor
	var center_anchors = resolver.find_center_anchors(r_geom, 2.0)
	assert(center_anchors.size() == 1, "FAIL: Expected 1 focal center anchor")
	assert(center_anchors[0].mode == PropPlacementModeScript.Mode.CENTER)
	assert(center_anchors[0].cell == Vector2i(4, 4) or center_anchors[0].cell == Vector2i(5, 5), "FAIL: Center anchor position incorrect")
	print("  [OK] Center anchor discovered at %s" % str(center_anchors[0].cell))

	# 4. Corner Anchors
	var corner_anchors = resolver.find_corner_anchors(r_geom, 2.0)
	assert(corner_anchors.size() == 4, "FAIL: Expected 4 corner anchors, got %d" % corner_anchors.size())
	assert(corner_anchors[0].mode == PropPlacementModeScript.Mode.CORNER)
	print("  [OK] Corner anchors discovered: %d" % corner_anchors.size())

	print("[PASS] test_prop_anchors completed successfully!")
	quit(0)
