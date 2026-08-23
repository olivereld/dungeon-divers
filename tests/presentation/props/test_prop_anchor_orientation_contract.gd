extends SceneTree

const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _DecorationOrientationResolverScript = preload("res://src/presentation/decoration/composition/decoration_orientation_resolver.gd")
const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")

func _init() -> void:
	print("--- Running test_prop_anchor_orientation_contract ---")

	var anchor_resolver := _PropAnchorResolverScript.new()
	var orientation_resolver := _DecorationOrientationResolverScript.new()

	# Create a mock 3x3 room geometry
	# (0,0) (1,0) (2,0)
	# (0,1) (1,1) (2,1)
	# (0,2) (1,2) (2,2)
	var floor_cells: Array[Vector2i] = []
	for x in range(3):
		for y in range(3):
			floor_cells.append(Vector2i(x, y))

	var mock_room = {
		"floor_cells": floor_cells,
		"door_positions": [],
		"stairs_cells": []
	}

	# 1. TEST WALL ANCHOR ORIENTATION CONTRACT (Degrees)
	var wall_anchors = anchor_resolver.find_wall_anchors(mock_room, 2.0)
	assert(wall_anchors.size() > 0, "Must discover wall anchors")

	for anchor in wall_anchors:
		# Center top (1, 0) has wall to North (0, -1) -> must face South (+Z, 0°)
		if anchor.cell == Vector2i(1, 0):
			assert(is_equal_approx(anchor.rotation_degrees_y, 0.0), "North wall anchor must be 0.0 deg, got %f" % anchor.rotation_degrees_y)
			print("  [OK] North Wall Anchor -> %0.1f deg (Faces South into room)" % anchor.rotation_degrees_y)

		# Center bottom (1, 2) has wall to South (0, 1) -> must face North (-Z, 180°)
		elif anchor.cell == Vector2i(1, 2):
			assert(is_equal_approx(anchor.rotation_degrees_y, 180.0), "South wall anchor must be 180.0 deg, got %f" % anchor.rotation_degrees_y)
			print("  [OK] South Wall Anchor -> %0.1f deg (Faces North into room)" % anchor.rotation_degrees_y)

		# Center left (0, 1) has wall to West (-1, 0) -> must face East (+X, 90°)
		elif anchor.cell == Vector2i(0, 1):
			assert(is_equal_approx(anchor.rotation_degrees_y, 90.0), "West wall anchor must be 90.0 deg, got %f" % anchor.rotation_degrees_y)
			print("  [OK] West Wall Anchor -> %0.1f deg (Faces East into room)" % anchor.rotation_degrees_y)

		# Center right (2, 1) has wall to East (1, 0) -> must face West (-X, 270°)
		elif anchor.cell == Vector2i(2, 1):
			assert(is_equal_approx(anchor.rotation_degrees_y, 270.0), "East wall anchor must be 270.0 deg, got %f" % anchor.rotation_degrees_y)
			print("  [OK] East Wall Anchor -> %0.1f deg (Faces West into room)" % anchor.rotation_degrees_y)

	# 2. TEST CORNER ANCHOR ORIENTATION CONTRACT (Degrees)
	var corner_anchors = anchor_resolver.find_corner_anchors(mock_room, 2.0)
	assert(corner_anchors.size() == 4, "Must discover 4 corners in 3x3 room")

	for c_anchor in corner_anchors:
		if c_anchor.cell == Vector2i(0, 0): # NW
			assert(is_equal_approx(c_anchor.rotation_degrees_y, 45.0), "NW corner must be 45 deg, got %f" % c_anchor.rotation_degrees_y)
		elif c_anchor.cell == Vector2i(2, 0): # NE
			assert(is_equal_approx(c_anchor.rotation_degrees_y, 315.0), "NE corner must be 315 deg, got %f" % c_anchor.rotation_degrees_y)
		elif c_anchor.cell == Vector2i(0, 2): # SW
			assert(is_equal_approx(c_anchor.rotation_degrees_y, 135.0), "SW corner must be 135 deg, got %f" % c_anchor.rotation_degrees_y)
		elif c_anchor.cell == Vector2i(2, 2): # SE
			assert(is_equal_approx(c_anchor.rotation_degrees_y, 225.0), "SE corner must be 225 deg, got %f" % c_anchor.rotation_degrees_y)

	print("  [OK] Corner Anchors NW(45°), NE(315°), SW(135°), SE(225°) verified.")

	# 3. TEST FULL PIPELINE: Wall Anchor (South Wall) -> FACE_ROOM -> PropDirective -> Node3D rotation
	var south_anchor = null
	for a in wall_anchors:
		if a.cell == Vector2i(1, 2):
			south_anchor = a
			break

	assert(south_anchor != null, "South anchor must exist")
	var resolved_deg = orientation_resolver.resolve_rotation(south_anchor, _DecorationOrientationModeScript.Mode.FACE_ROOM)
	assert(is_equal_approx(resolved_deg, 180.0), "Resolved rotation must be 180.0 deg, got %f" % resolved_deg)

	var bench_style := _PropStyleScript.new(
		&"test_bench",
		_PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL,
		_PropCollisionModeScript.Mode.BLOCKING,
		null,
		&"bench_prop",
		{"style": 0}
	)

	var directive := _PropDirectiveScript.new(
		&"church_pew_wall",
		0,
		bench_style,
		south_anchor.world_position,
		resolved_deg,
		[south_anchor.cell],
		_PropPlacementModeScript.Mode.WALL,
		_PropCollisionModeScript.Mode.BLOCKING
	)

	var spawner := _PropSpawnerScript.new()
	var spawned_node = spawner.spawn_prop(directive)
	assert(spawned_node != null, "Spawned node must not be null")
	assert(is_equal_approx(spawned_node.rotation.y, PI), "Node3D rotation.y on South wall must be exactly PI rad (180 deg), got %f" % spawned_node.rotation.y)

	print("  [OK] Pipeline verified: South Wall Bench rotated exactly PI rad (180°) facing room interior")

	spawned_node.free()
	print("[PASS] test_prop_anchor_orientation_contract completed successfully!")
	quit(0)
