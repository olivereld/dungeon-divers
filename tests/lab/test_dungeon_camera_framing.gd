extends SceneTree

const _FramingScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_framing.gd")

func _init() -> void:
	print("--- Running test_dungeon_camera_framing ---")
	
	# 1. Normal Dungeon (32x32)
	var f32 = _FramingScript.compute_framing(Vector3(0, 0, 0), Vector3(32, 4, 32))
	assert(f32["center"] == Vector3(16, 2, 16), "FAIL: Center of 32x32 dungeon should be (16, 2, 16)")
	assert(f32["ortho_size"] > 32.0, "FAIL: Ortho size should be greater than dimension with margin")
	assert(f32["is_degenerate"] == false, "FAIL: 32x32 must not be degenerate")
	print("  [OK] 32x32 framing computed: center=%s, ortho_size=%.1f" % [str(f32["center"]), f32["ortho_size"]])
	
	# 2. Large Dungeon (64x64)
	var f64 = _FramingScript.compute_framing(Vector3(0, 0, 0), Vector3(64, 4, 64))
	assert(f64["ortho_size"] > f32["ortho_size"], "FAIL: 64x64 ortho size must scale proportionally")
	print("  [OK] 64x64 framing computed: center=%s, ortho_size=%.1f" % [str(f64["center"]), f64["ortho_size"]])
	
	# 3. Huge Dungeon (128x128)
	var f128 = _FramingScript.compute_framing(Vector3(0, 0, 0), Vector3(128, 4, 128))
	assert(f128["ortho_size"] > f64["ortho_size"], "FAIL: 128x128 ortho size must scale proportionally")
	print("  [OK] 128x128 framing computed: center=%s, ortho_size=%.1f" % [str(f128["center"]), f128["ortho_size"]])
	
	# 4. Degenerate Case (Empty / Size 0)
	var f_deg = _FramingScript.compute_framing(Vector3.ZERO, Vector3.ZERO)
	assert(f_deg["is_degenerate"] == true, "FAIL: Size 0 must be marked degenerate")
	assert(f_deg["ortho_size"] >= 10.0, "FAIL: Degenerate case must use safe default ortho size")
	assert(not is_nan(f_deg["ortho_size"]) and not is_inf(f_deg["ortho_size"]), "FAIL: Ortho size must not be NaN/INF")
	print("  [OK] Degenerate AABB correctly handled with fallback ortho_size=%.1f" % f_deg["ortho_size"])
	
	# 5. Hierarchy AABB Computation
	var root_test := Node3D.new()
	var child1 := Node3D.new()
	child1.position = Vector3(10, 0, 20)
	root_test.add_child(child1)
	var child2 := Node3D.new()
	child2.position = Vector3(-5, 3, -10)
	root_test.add_child(child2)
	
	var aabb_res = _FramingScript.compute_hierarchy_aabb(root_test)
	assert(aabb_res["valid"] == true, "FAIL: Valid hierarchy AABB expected")
	assert(aabb_res["min"] == Vector3(-5, 0, -10), "FAIL: AABB min mismatch")
	assert(aabb_res["max"] == Vector3(10, 3, 20), "FAIL: AABB max mismatch")
	root_test.free()
	print("  [OK] Hierarchy AABB successfully computed from node tree")
	
	print("PASS: test_dungeon_camera_framing passed 100%!")
	quit(0)
