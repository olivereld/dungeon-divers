extends SceneTree

const _PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_corridor_torch_spawning ---")
	print("==================================================================")

	var partition = _PresentationGeometryPartitionScript.new()
	var resolver = _FixtureAnchorResolverScript.new()

	# Corridor floor (5 tiles long horizontal path)
	for x in range(5, 10):
		partition.corridor_floor_cells.append(Vector2i(x, 5))

	# Corridor walls (North and South walls)
	for x in range(5, 10):
		partition.corridor_wall_cells.append(Vector2i(x, 4)) # North wall
		partition.corridor_wall_cells.append(Vector2i(x, 6)) # South wall

	var anchors = resolver.find_corridor_wall_anchors(partition, 2.0)
	assert(not anchors.is_empty(), "FAIL: Must find corridor wall anchors")
	assert(anchors.size() == 10, "FAIL: Expected 10 corridor wall anchors, found %d" % anchors.size())

	for a in anchors:
		print("  Corridor Wall Anchor at cell: ", a.cell, " pos: ", a.position, " side: ", a.wall_side)

	print("  [OK] Corridor wall anchors discovered correctly.")
	print("==================================================================")
	print("[PASS] test_corridor_torch_spawning passed successfully!")
	print("==================================================================")
	quit(0)
