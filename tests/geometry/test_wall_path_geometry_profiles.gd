# tests/geometry/test_wall_path_geometry_profiles.gd
extends SceneTree

const _WallPathGeometryScript = preload("res://src/geometry_generator/geometry/wall_path_geometry.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_path_geometry_profiles ---")
	print("==================================================================")

	var cfg := _WallGeometryConfigScript.new()
	cfg.cube_size = 2.0
	cfg.cubes_high = 2

	var w_thin: float = cfg.wall_thickness
	var d: float = cfg.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)
	var tile: float = cfg.cube_size

	# Test 1: from_component_loop with a rectangle — profiles populated
	var comp := _WallComponentScript.new(1)
	comp.add_loop([Vector2i(0, 0), Vector2i(4, 0), Vector2i(4, 3), Vector2i(0, 3)])
	var pg = _WallPathGeometryScript.from_component_loop(comp.loops[0], 1, cfg)
	assert(pg.profiles.size() == 4, "T1: must have 4 profiles for rectangle")
	for j in range(4):
		var pf = pg.profiles[j]
		# inner_thick must lie on the centerline (corner point)
		assert(pf.inner_thick.distance_to(pg.points_3d[j]) < 0.001,
			"T1: inner_thick[%d] must be on centerline" % j)
		# outer_thick must be offset from inner_thick
		assert(pf.outer_thick.distance_to(pf.inner_thick) > w_thick * 0.5,
			"T1: outer_thick[%d] must be displaced from inner_thick" % j)

	# Test 2: Adjacent profile vertices for a straight segment share consistent offset distance
	var pf0 = pg.profiles[0]
	var pf1 = pg.profiles[1]
	var d_pf0 := absf(pf0.inner_thin.z - pg.points_3d[0].z)
	var d_pf1 := absf(pf1.inner_thin.z - pg.points_3d[1].z)
	assert(absf(d_pf0 - d_pf1) < 0.001,
		"T2: inner_thin offset from segment must be consistent across straight segment")

	# Test 3: from_section preserves same geometry
	var sec := _WallSectionScript.new(0, 1,
		[Vector2i(0, 0), Vector2i(4, 0), Vector2i(4, 3), Vector2i(0, 3)],
		1, &"normal", true)
	sec.corner_ids = [100000, 100001, 100002, 100003]
	sec.set_start_corner(100000, Vector2i(0, 3), true)
	sec.set_end_corner(100003, Vector2i(4, 0), true)
	sec.has_start_cap = false
	sec.has_end_cap = false
	var pg_sec = _WallPathGeometryScript.from_section(sec, cfg)
	assert(pg_sec.profiles.size() == 4, "T3: section profiles must have 4 entries")

	print("  [OK] WallPathGeometry produces offset-profile-based ProfileVertex arrays")
	print("==================================================================")
	print("[PASS] test_wall_path_geometry_profiles completado con éxito!")
	print("==================================================================")
	quit(0)
