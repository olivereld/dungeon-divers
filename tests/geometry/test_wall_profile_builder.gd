# tests/geometry/test_wall_profile_builder.gd
extends SceneTree

const _WallProfileBuilderScript = preload("res://src/geometry_generator/geometry/wall_profile_builder.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_profile_builder (Offset Profile Geometry) ---")
	print("==================================================================")

	var builder := _WallProfileBuilderScript.new()

	# Test 1: 90° convex corner offset intersection
	# Segment A: (0,0,0) → (4,0,0), Segment B: (4,0,0) → (4,0,4)
	# Offset = 0.5 to the left (interior normal side)
	# Seg A normal (left) = (0, 0, 1), offset line: y=0, z=0.5, x ∈ [0,4]
	# Seg B normal (left) = (-1, 0, 0), offset line: y=0, x=3.5, z ∈ [0,4]
	# Intersection at (3.5, 0, 0.5)
	var p := builder.compute_offset_intersection(
		Vector3(0, 0, 0), Vector3(4, 0, 0),  # seg A
		Vector3(4, 0, 0), Vector3(4, 0, 4),  # seg B
		0.5  # offset distance
	)
	assert(p.distance_to(Vector3(3.5, 0.0, 0.5)) < 0.001,
		"TEST 1 FAIL: 90° offset intersection expected (3.5, 0, 0.5) got %s" % str(p))
	print("  [OK] Test 1: 90° convex offset intersection = (3.5, 0, 0.5)")

	# Test 2: Same corner, larger offset = 1.0
	# Seg A offset line: z=1.0; Seg B offset line: x=3.0
	# Intersection at (3.0, 0, 1.0)
	var p2 := builder.compute_offset_intersection(
		Vector3(0, 0, 0), Vector3(4, 0, 0),
		Vector3(4, 0, 0), Vector3(4, 0, 4),
		1.0
	)
	assert(p2.distance_to(Vector3(3.0, 0.0, 1.0)) < 0.001,
		"TEST 2 FAIL: offset=1.0 expected (3.0, 0, 1.0) got %s" % str(p2))
	print("  [OK] Test 2: 90° convex offset=1.0 intersection = (3.0, 0, 1.0)")

	# Test 3: Collinear segments (180°) — offset intersection degenerates to simple offset
	var p3 := builder.compute_offset_intersection(
		Vector3(0, 0, 0), Vector3(2, 0, 0),
		Vector3(2, 0, 0), Vector3(4, 0, 0),
		0.5
	)
	assert(p3.distance_to(Vector3(2.0, 0.0, 0.5)) < 0.001,
		"TEST 3 FAIL: collinear offset expected (2.0, 0, 0.5) got %s" % str(p3))
	print("  [OK] Test 3: Collinear offset intersection at midpoint")

	# Test 4: Full ProfileVertex for 90° corner — all 4 offsets are independent
	# w_thick = 0.54, w_thin = 0.38, d = 0.08
	# inner_thick: offset 0 (on centerline)
	# inner_thin: offset d*0.5 = 0.04
	# outer_thin: offset w_thick - d*0.5 = 0.50
	# outer_thick: offset w_thick = 0.54
	var pv := builder.compute_profile_vertex(
		Vector3(0, 0, 0), Vector3(4, 0, 0),
		Vector3(4, 0, 0), Vector3(4, 0, 4),
		0.54, 0.38, 0.08
	)
	# inner_thick is at the corner point on the centerline = (4, 0, 0)
	assert(pv.inner_thick.distance_to(Vector3(4.0, 0.0, 0.0)) < 0.001,
		"TEST 4a FAIL: inner_thick = corner point")
	# inner_thin: offset = 0.04, intersection of offset lines
	assert(pv.inner_thin.distance_to(Vector3(3.96, 0.0, 0.04)) < 0.001,
		"TEST 4b FAIL: inner_thin at offset 0.04")
	# outer_thin: offset = 0.50
	assert(pv.outer_thin.distance_to(Vector3(3.50, 0.0, 0.50)) < 0.001,
		"TEST 4c FAIL: outer_thin at offset 0.50")
	# outer_thick: offset = 0.54
	assert(pv.outer_thick.distance_to(Vector3(3.46, 0.0, 0.54)) < 0.001,
		"TEST 4d FAIL: outer_thick at offset 0.54")
	print("  [OK] Test 4: ProfileVertex 4 independent offsets at 90° corner")

	# Test 5: 45° corner
	# Seg A: (0,0,0) → (4,0,0), Seg B: (4,0,0) → (6,0,2) (45° turn)
	var pv45 := builder.compute_profile_vertex(
		Vector3(0, 0, 0), Vector3(4, 0, 0),
		Vector3(4, 0, 0), Vector3(6, 0, 2),
		0.54, 0.38, 0.08
	)
	assert(pv45.inner_thick.distance_to(pv45.inner_thin) > 0.01, "TEST 5a: inner points must differ")
	assert(pv45.inner_thin.distance_to(pv45.outer_thin) > 0.1, "TEST 5b: panel width must be positive")
	assert(pv45.outer_thin.distance_to(pv45.outer_thick) > 0.01, "TEST 5c: outer points must differ")

	var d_inner_thin_from_a := _perp_distance_xz(pv45.inner_thin,
		Vector3(0, 0, 0), Vector3(4, 0, 0))
	assert(absf(d_inner_thin_from_a - 0.04) < 0.001,
		"TEST 5d: inner_thin must be 0.04 from seg A, got %.4f" % d_inner_thin_from_a)
	var d_outer_thick_from_a := _perp_distance_xz(pv45.outer_thick,
		Vector3(0, 0, 0), Vector3(4, 0, 0))
	assert(absf(d_outer_thick_from_a - 0.54) < 0.001,
		"TEST 5e: outer_thick must be 0.54 from seg A, got %.4f" % d_outer_thick_from_a)
	print("  [OK] Test 5: 45° corner — perpendicular distance invariant holds for all offsets")

	# Test 6: compute_path_profiles for a closed rectangle
	var rect_pts: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(8, 0, 6), Vector3(0, 0, 6)
	]
	var profiles := builder.compute_path_profiles(
		rect_pts, true, Vector3.INF, Vector3.INF, 0.54, 0.38, 0.08
	)
	assert(profiles.size() == 4, "TEST 6a: 4 profile vertices for rectangle")
	for j in range(4):
		var pf = profiles[j]
		assert(pf.inner_thick.distance_to(rect_pts[j]) < 0.001,
			"TEST 6b: inner_thick[%d] must match corner point" % j)
	print("  [OK] Test 6: Closed rectangle path produces 4 consistent profile vertices")

	print("==================================================================")
	print("[PASS] test_wall_profile_builder completado con 100% éxito!")
	print("==================================================================")
	quit(0)

func _perp_distance_xz(point: Vector3, line_a: Vector3, line_b: Vector3) -> float:
	var d := line_b - line_a
	var t := Vector2(d.x, d.z)
	var n := Vector2(-t.y, t.x).normalized()
	var p := Vector2(point.x - line_a.x, point.z - line_a.z)
	return absf(p.dot(n))
