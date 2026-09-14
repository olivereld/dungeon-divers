extends SceneTree

const _HydraulicCarvingProfileScript = preload("res://src/world_generator/hydrology/hydraulic_carving_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running HydraulicCarvingProfile Unit Tests")
	print("==================================================")

	# 1. Test River Centerline Profile
	print(" [CHECK] 1. River Centerline Profile Continuity and Boundaries...")
	var river_prof = _HydraulicCarvingProfileScript.create_for_river(
		0.40,  # bed_depth
		1.0,   # bed_width
		1.5,   # transition_width
		3.0,   # bank_width
		0.25,  # freeboard
		2.0    # slope_factor
	)

	var water_y: float = 10.0
	var raw_y: float = 12.0
	var bed_y: float = water_y - 0.40

	# Bed flat region: d <= 1.0
	assert(is_equal_approx(river_prof.evaluate_centerline(0.0, water_y, raw_y), bed_y), "Centerline d=0 must equal bed_y")
	assert(is_equal_approx(river_prof.evaluate_centerline(1.0, water_y, raw_y), bed_y), "Centerline d=bed_width must equal bed_y")

	# Submerged transition: 1.0 < d < 2.5
	var mid_sub: float = river_prof.evaluate_centerline(1.75, water_y, raw_y)
	assert(mid_sub > bed_y and mid_sub < water_y, "Submerged transition must lie strictly between bed_y and water_y")

	# Waterline: d = 1.0 + 1.5 = 2.5
	assert(is_equal_approx(river_prof.evaluate_centerline(2.5, water_y, raw_y), water_y), "Centerline d=water_radius must be exact water_y")

	# Bank slope: 2.5 < d < 5.5
	var mid_bank: float = river_prof.evaluate_centerline(4.0, water_y, raw_y)
	assert(mid_bank > water_y and mid_bank < raw_y, "Bank slope must lie between water_y and raw_y")

	# Raw terrain: d >= 5.5
	assert(is_equal_approx(river_prof.evaluate_centerline(5.5, water_y, raw_y), raw_y), "Bank boundary must match raw_y")
	assert(is_equal_approx(river_prof.evaluate_centerline(10.0, water_y, raw_y), raw_y), "Far field must equal raw_y")

	# C0 Continuity checks across transitions
	var eps: float = 0.0001
	assert(absf(river_prof.evaluate_centerline(1.0 - eps, water_y, raw_y) - river_prof.evaluate_centerline(1.0 + eps, water_y, raw_y)) < 0.01, "C0 continuity at bed boundary")
	assert(absf(river_prof.evaluate_centerline(2.5 - eps, water_y, raw_y) - river_prof.evaluate_centerline(2.5 + eps, water_y, raw_y)) < 0.01, "C0 continuity at waterline")
	assert(absf(river_prof.evaluate_centerline(5.5 - eps, water_y, raw_y) - river_prof.evaluate_centerline(5.5 + eps, water_y, raw_y)) < 0.01, "C0 continuity at crest boundary")
	print("   River Centerline Profile: PASSED")

	# 2. Test Lake Boundary Profile (Signed Distance)
	print(" [CHECK] 2. Lake Boundary Profile Continuity and Boundaries...")
	var lake_prof = _HydraulicCarvingProfileScript.create_for_lake(
		0.45,  # bed_depth
		2.0,   # submerged_ramp_width
		3.5,   # bank_width
		0.30,  # freeboard
		2.0    # slope_factor
	)

	var lake_bed_y: float = water_y - 0.45

	# Deep lake bed: d <= -2.0
	assert(is_equal_approx(lake_prof.evaluate_boundary(-5.0, water_y, raw_y), lake_bed_y), "Deep lake bed must equal bed_y")
	assert(is_equal_approx(lake_prof.evaluate_boundary(-2.0, water_y, raw_y), lake_bed_y), "Lake bed transition start must equal bed_y")

	# Submerged ramp: -2.0 < d < 0
	var lake_mid_sub: float = lake_prof.evaluate_boundary(-1.0, water_y, raw_y)
	assert(lake_mid_sub > lake_bed_y and lake_mid_sub < water_y, "Lake submerged ramp must lie strictly between bed_y and water_y")

	# Waterline: d = 0
	assert(is_equal_approx(lake_prof.evaluate_boundary(0.0, water_y, raw_y), water_y), "Lake boundary d=0 must equal exact water_y")

	# Outer bank slope: 0 < d < 3.5
	var lake_mid_bank: float = lake_prof.evaluate_boundary(1.75, water_y, raw_y)
	assert(lake_mid_bank > water_y and lake_mid_bank < raw_y, "Lake bank slope must lie between water_y and raw_y")

	# Outer terrain: d >= 3.5
	assert(is_equal_approx(lake_prof.evaluate_boundary(3.5, water_y, raw_y), raw_y), "Lake bank crest must match raw_y")
	assert(is_equal_approx(lake_prof.evaluate_boundary(8.0, water_y, raw_y), raw_y), "Lake far field must match raw_y")

	# C0 Continuity checks
	assert(absf(lake_prof.evaluate_boundary(-2.0 - eps, water_y, raw_y) - lake_prof.evaluate_boundary(-2.0 + eps, water_y, raw_y)) < 0.01, "C0 continuity at lake bed ramp start")
	assert(absf(lake_prof.evaluate_boundary(-eps, water_y, raw_y) - lake_prof.evaluate_boundary(eps, water_y, raw_y)) < 0.01, "C0 continuity at lake waterline")
	assert(absf(lake_prof.evaluate_boundary(3.5 - eps, water_y, raw_y) - lake_prof.evaluate_boundary(3.5 + eps, water_y, raw_y)) < 0.01, "C0 continuity at lake crest boundary")
	print("   Lake Boundary Profile: PASSED")

	# 3. Test Hydraulic Influence Scalar Mask
	print(" [CHECK] 3. Hydraulic Influence Scalar Mask (0.0 to 1.0)...")
	# River influence
	assert(is_equal_approx(river_prof.evaluate_influence_centerline(0.0), 1.0), "River center influence must be 1.0")
	assert(is_equal_approx(river_prof.evaluate_influence_centerline(1.0), 1.0), "River bed influence must be 1.0")
	assert(is_equal_approx(river_prof.evaluate_influence_centerline(2.5), 1.0), "River waterline influence must be 1.0")
	var river_inf_mid: float = river_prof.evaluate_influence_centerline(4.0)
	assert(river_inf_mid > 0.0 and river_inf_mid < 1.0, "River bank influence must be strictly between 0 and 1")
	assert(is_equal_approx(river_prof.evaluate_influence_centerline(5.5), 0.0), "River bank boundary influence must be 0.0")
	assert(is_equal_approx(river_prof.evaluate_influence_centerline(12.0), 0.0), "River far field influence must be 0.0")

	# Lake influence
	assert(is_equal_approx(lake_prof.evaluate_influence_boundary(-5.0), 1.0), "Lake interior influence must be 1.0")
	assert(is_equal_approx(lake_prof.evaluate_influence_boundary(0.0), 1.0), "Lake waterline influence must be 1.0")
	var lake_inf_mid: float = lake_prof.evaluate_influence_boundary(1.75)
	assert(lake_inf_mid > 0.0 and lake_inf_mid < 1.0, "Lake bank influence must be strictly between 0 and 1")
	assert(is_equal_approx(lake_prof.evaluate_influence_boundary(3.5), 0.0), "Lake bank boundary influence must be 0.0")
	assert(is_equal_approx(lake_prof.evaluate_influence_boundary(10.0), 0.0), "Lake far field influence must be 0.0")

	# Blending formula identity: final_h == lerpf(raw_y, carved_h, influence)
	for test_d in [0.0, 1.0, 2.0, 2.5, 3.5, 4.0, 5.0, 5.5, 7.0]:
		var inf: float = river_prof.evaluate_influence_centerline(test_d)
		var carved_h: float = river_prof.evaluate_carved_height_centerline(test_d, water_y)
		var blended_h: float = lerpf(raw_y, carved_h, inf)
		var direct_h: float = river_prof.evaluate_centerline(test_d, water_y, raw_y)
		assert(is_equal_approx(blended_h, direct_h), "Blending formula must match evaluate_centerline at d=%.2f" % test_d)
	print("   Hydraulic Influence Mask: PASSED")

	# 4. Test water_y vs bed_y separation (Bloque 7)
	print(" [CHECK] 4. Strict water_y vs bed_y Separation (e.g. water=20, bed=17, depth=3m)...")
	var wy: float = 20.0
	var depth_3m: float = 3.0
	var raw_high: float = 24.0

	# Bed floor: signed_d <= -2.0
	var bed_sample: float = lake_prof.evaluate_boundary(-4.0, wy, raw_high, depth_3m)
	assert(is_equal_approx(bed_sample, 17.0), "Deep bed must be exactly 17.0, got %.3f" % bed_sample)

	# Waterline: signed_d = 0.0
	var waterline_sample: float = lake_prof.evaluate_boundary(0.0, wy, raw_high, depth_3m)
	assert(is_equal_approx(waterline_sample, 20.0), "Waterline must be exactly 20.0, got %.3f" % waterline_sample)

	# Submerged ramp: -2.0 < signed_d < 0.0
	var ramp_sample: float = lake_prof.evaluate_boundary(-1.0, wy, raw_high, depth_3m)
	assert(ramp_sample > 17.0 and ramp_sample < 20.0, "Submerged ramp must be strictly between 17 and 20, got %.3f" % ramp_sample)

	# Outer bank: 0.0 < signed_d < 3.5
	var bank_sample: float = lake_prof.evaluate_boundary(1.75, wy, raw_high, depth_3m)
	assert(bank_sample > 20.0 and bank_sample < 24.0, "Outer bank must be strictly between 20 and 24, got %.3f" % bank_sample)

	# Far field: signed_d >= 3.5
	var raw_sample: float = lake_prof.evaluate_boundary(5.0, wy, raw_high, depth_3m)
	assert(is_equal_approx(raw_sample, 24.0), "Far field must be exactly raw_high (24.0), got %.3f" % raw_sample)
	print("   Strict water_y vs bed_y Separation: PASSED")

	# 5. Test Strictly Destructive Carving Invariant (H_carved <= H_raw)
	print(" [CHECK] 5. Strictly Destructive Carving Invariant (H_carved <= H_raw)...")
	var raw_low: float = 10.0
	var water_high: float = 14.0

	for d in [0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 6.0]:
		var res_river: float = river_prof.evaluate_centerline(d, water_high, raw_low)
		assert(res_river <= raw_low + 0.0001, "River carving at d=%.2f must never exceed raw_low (got %.3f > %.3f)" % [d, res_river, raw_low])

	for sd in [-3.0, -1.5, 0.0, 1.0, 2.5, 5.0]:
		var res_lake: float = lake_prof.evaluate_boundary(sd, water_high, raw_low)
		assert(res_lake <= raw_low + 0.0001, "Lake carving at sd=%.2f must never exceed raw_low (got %.3f > %.3f)" % [sd, res_lake, raw_low])
	print("   Strictly Destructive Carving Invariant: PASSED")

	print("==================================================")
	print(" ALL HYDRAULIC CARVING PROFILE TESTS PASSED!")
	print("==================================================")
	quit(0)
