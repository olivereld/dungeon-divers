extends SceneTree

const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")
const _ViewerScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_3d_viewer.gd")
const _FramingScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_framing.gd")
const _PresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _GoldenFixtureManagerScript = preload("res://src/dungeon_generator/debug/golden_fixture_manager.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_lab_viewer (10-Point Suite) ---")
	print("==================================================================")
	
	# 1. Instantiation of Lab Scene with Viewer
	var lab = _LabScene.instantiate()
	assert(lab != null, "FAIL: Could not instantiate dungeon_level_lab.tscn")
	root.add_child(lab)
	lab._ready()
	
	var viewer: _ViewerScript = lab.viewer_3d
	assert(viewer != null, "FAIL: 3D Viewer must be present in DungeonLevelLab")
	print("  [OK] Point 1: Lab scene and 3D Viewer successfully instantiated")
	
	# 2. Generation -> Semantic Result != null
	lab.config.seed = 100001
	lab.config.floor_count = 1
	lab.generate_current()
	var sem_res = lab.controller.get_active_semantic_result()
	assert(sem_res != null, "FAIL: Generation must produce valid semantic result")
	assert(sem_res.rooms.size() > 0, "FAIL: Generation must produce rooms")
	print("  [OK] Point 2: Generation produced valid semantic result (%d rooms)" % sem_res.rooms.size())
	
	# 3. Presentation Materialization via Viewer
	assert(viewer._current_presentation != null, "FAIL: Viewer must hold active presentation node")
	assert(viewer.dungeon_root.get_child_count() == 1, "FAIL: DungeonRoot must contain exactly 1 active presentation")
	print("  [OK] Point 3: Presentation built and mounted in DungeonRoot")
	
	# 4. Bounding Box Calculation
	var bounds: Dictionary = viewer.get_dungeon_bounds()
	assert(bounds["min"] != Vector3.ZERO or bounds["max"] != Vector3.ZERO, "FAIL: Bounds must be non-zero for populated dungeon")
	print("  [OK] Point 4: Dungeon bounds computed: min=%s, max=%s, center=%s" % [str(bounds["min"]), str(bounds["max"]), str(bounds["center"])])
	
	# 5. Camera Target & Framing Match Center
	assert(viewer.camera_rig != null, "FAIL: CameraRig must be present")
	var target_diff: float = (viewer.camera_rig.target_position - bounds["center"]).length()
	assert(target_diff < 0.01, "FAIL: Camera target must match bounds center (diff: %f)" % target_diff)
	assert(viewer.camera_rig.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "FAIL: Camera must be Orthogonal")
	print("  [OK] Point 5: Camera target matches dungeon center perfectly")
	
	# 6. Rebuild 10 Times Without Node Accumulation / Memory Leaks
	for i in range(10):
		lab.config.seed = 100001 + i
		lab.generate_current()
		assert(viewer.dungeon_root.get_child_count() == 1, "FAIL: Accumulation detected! Expected 1 child, got %d" % viewer.dungeon_root.get_child_count())
	print("  [OK] Point 6: 10 successive regenerations maintained exactly 1 presentation child in DungeonRoot")
	
	# 7. Degenerate / Empty Result Handling
	viewer.load_dungeon(null)
	assert(viewer.dungeon_root.get_child_count() == 0, "FAIL: DungeonRoot must be empty after loading null")
	var deg_bounds = viewer.get_dungeon_bounds()
	assert(deg_bounds["center"] == Vector3.ZERO, "FAIL: Degenerate bounds center must be ZERO")
	print("  [OK] Point 7: Degenerate null load safely handled without crash")
	
	# 8. Generation Failure Handling
	viewer.on_generation_failed("Mock pipeline error")
	assert(viewer.dungeon_root.get_child_count() == 0, "FAIL: Failure handler must clear presentation")
	print("  [OK] Point 8: Generation failure safely resets viewer")
	
	# 9. Multi-Floor Sync (Floor Changing)
	lab.seed_input.value = 100001
	lab.floor_spin.value = 2
	lab.generate_current()
	var multi_res = lab.controller.get_multi_floor_result()
	assert(multi_res != null and multi_res.get_floor_count() == 2, "FAIL: Multi-floor generation failed")
	assert(viewer.dungeon_root.get_child_count() == 1, "FAIL: Initial floor 0 presentation mounted")
	
	# Switch to Floor 1
	lab.controller.set_current_floor(1)
	assert(viewer.dungeon_root.get_child_count() == 1, "FAIL: Floor 1 switch must replace presentation without stacking")
	print("  [OK] Point 9: Multi-floor floor_changed correctly re-renders active floor only")
	
	# 10. Golden Fixtures 20/20 Check
	var gfm := _GoldenFixtureManagerScript.new()
	var report: Dictionary = gfm.verify_golden_seeds(1)
	assert(report.get("matched_seeds", 0) == 20, "FAIL: Golden fixtures regression detected!")
	print("  [OK] Point 10: Golden Fixtures 20/20 PASS with 0 drift")
	
	lab.queue_free()
	print("==================================================================")
	print(">>> ALL 10 POINTS IN 3D VIEWER INTEGRATION PASSED 100%! <<<")
	print("==================================================================")
	quit(0)
