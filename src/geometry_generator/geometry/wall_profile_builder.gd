class_name WallProfileBuilder
extends RefCounted

## Builds wall profile geometry using per-segment offset line intersections.
## Each profile level (inner_thick, inner_thin, outer_thin, outer_thick) gets
## its own parallel offset line per segment. Corner vertices are the intersection
## of adjacent segment offset lines at each level independently.
## This replaces the incorrect point + miter * offset approach.

class ProfileVertex extends RefCounted:
	var inner_thick: Vector3 = Vector3.ZERO  # offset = 0 (centerline)
	var inner_thin: Vector3 = Vector3.ZERO   # offset = d * 0.5
	var outer_thin: Vector3 = Vector3.ZERO   # offset = w_thick - d * 0.5
	var outer_thick: Vector3 = Vector3.ZERO  # offset = w_thick

## Computes the intersection of two offset lines in the XZ plane.
## Each offset line is the segment's line shifted perpendicular by `offset` distance.
## The normal direction is to the LEFT of the segment's travel direction (XZ plane, Y up).
## Returns the intersection point (Y=0).
func compute_offset_intersection(
	seg_a_start: Vector3, seg_a_end: Vector3,
	seg_b_start: Vector3, seg_b_end: Vector3,
	offset: float
) -> Vector3:
	var dir_a := seg_a_end - seg_a_start
	var dir_b := seg_b_end - seg_b_start
	var len_a := Vector2(dir_a.x, dir_a.z).length()
	var len_b := Vector2(dir_b.x, dir_b.z).length()

	if len_a < 0.0001 or len_b < 0.0001:
		# Degenerate segment — return corner with simple offset
		var fallback_dir := dir_a if len_a >= len_b else dir_b
		var fallback_len := len_a if len_a >= len_b else len_b
		var corner := seg_a_end if len_a >= 0.0001 else seg_b_start
		if fallback_len < 0.0001:
			return corner
		var t2 := Vector2(fallback_dir.x, fallback_dir.z).normalized()
		var n2 := Vector2(-t2.y, t2.x)  # left normal
		return corner + Vector3(n2.x * offset, 0.0, n2.y * offset)

	# Normals (left of travel direction in XZ)
	var t_a := Vector2(dir_a.x, dir_a.z).normalized()
	var n_a := Vector2(-t_a.y, t_a.x)
	var t_b := Vector2(dir_b.x, dir_b.z).normalized()
	var n_b := Vector2(-t_b.y, t_b.x)

	# Offset lines:
	# Line A: passes through (seg_a_start.xz + n_a * offset), direction t_a
	# Line B: passes through (seg_b_start.xz + n_b * offset), direction t_b
	var pa := Vector2(seg_a_start.x, seg_a_start.z) + n_a * offset
	var pb := Vector2(seg_b_start.x, seg_b_start.z) + n_b * offset

	# Intersect: pa + t_a * s = pb + t_b * t
	# Solve via 2x2 system: t_a.x * s - t_b.x * t = pb.x - pa.x
	#                        t_a.y * s - t_b.y * t = pb.y - pa.y
	var det := t_a.x * (-t_b.y) - t_a.y * (-t_b.x)
	if absf(det) < 0.000001:
		# Parallel lines (collinear segments) — return midpoint offset
		var corner_2d := Vector2(seg_a_end.x, seg_a_end.z)
		var offset_pt := corner_2d + n_a * offset
		return Vector3(offset_pt.x, 0.0, offset_pt.y)

	var dx := pb.x - pa.x
	var dy := pb.y - pa.y
	var s := (dx * (-t_b.y) - dy * (-t_b.x)) / det

	var result_2d := pa + t_a * s
	return Vector3(result_2d.x, 0.0, result_2d.y)

## Computes a complete ProfileVertex for the corner between two segments.
## Each of the 4 profile offsets gets its own independent line intersection.
func compute_profile_vertex(
	seg_a_start: Vector3, seg_a_end: Vector3,
	seg_b_start: Vector3, seg_b_end: Vector3,
	w_thick: float, w_thin: float, d: float
) -> ProfileVertex:
	var pv := ProfileVertex.new()

	var off_inner_thick: float = 0.0
	var off_inner_thin: float = d * 0.5
	var off_outer_thin: float = w_thick - (d * 0.5)
	var off_outer_thick: float = w_thick

	# inner_thick at offset=0 is the corner point itself (on centerline)
	pv.inner_thick = compute_offset_intersection(seg_a_start, seg_a_end, seg_b_start, seg_b_end, off_inner_thick)
	pv.inner_thin = compute_offset_intersection(seg_a_start, seg_a_end, seg_b_start, seg_b_end, off_inner_thin)
	pv.outer_thin = compute_offset_intersection(seg_a_start, seg_a_end, seg_b_start, seg_b_end, off_outer_thin)
	pv.outer_thick = compute_offset_intersection(seg_a_start, seg_a_end, seg_b_start, seg_b_end, off_outer_thick)

	return pv

## Computes profile vertices for all corners of a wall path.
func compute_path_profiles(
	pts_3d: Array[Vector3],
	is_closed: bool,
	start_neighbor_3d: Vector3 = Vector3.INF,
	end_neighbor_3d: Vector3 = Vector3.INF,
	w_thick: float = 0.54,
	w_thin: float = 0.38,
	d: float = 0.08
) -> Array[ProfileVertex]:
	var profiles: Array[ProfileVertex] = []
	var n: int = pts_3d.size()
	if n < 2:
		return profiles

	for i in range(n):
		var seg_a_start: Vector3
		var seg_a_end: Vector3
		var seg_b_start: Vector3
		var seg_b_end: Vector3

		if is_closed:
			seg_a_start = pts_3d[(i - 1 + n) % n]
			seg_a_end = pts_3d[i]
			seg_b_start = pts_3d[i]
			seg_b_end = pts_3d[(i + 1) % n]
		else:
			if i == 0:
				if not is_inf(start_neighbor_3d.x):
					seg_a_start = start_neighbor_3d
				else:
					seg_a_start = pts_3d[0]  # will produce simple offset
				seg_a_end = pts_3d[0]
				seg_b_start = pts_3d[0]
				seg_b_end = pts_3d[1]
			elif i == n - 1:
				seg_a_start = pts_3d[n - 2]
				seg_a_end = pts_3d[n - 1]
				seg_b_start = pts_3d[n - 1]
				if not is_inf(end_neighbor_3d.x):
					seg_b_end = end_neighbor_3d
				else:
					seg_b_end = pts_3d[n - 1]  # will produce simple offset
			else:
				seg_a_start = pts_3d[i - 1]
				seg_a_end = pts_3d[i]
				seg_b_start = pts_3d[i]
				seg_b_end = pts_3d[i + 1]

		profiles.append(compute_profile_vertex(
			seg_a_start, seg_a_end, seg_b_start, seg_b_end,
			w_thick, w_thin, d
		))

	return profiles
