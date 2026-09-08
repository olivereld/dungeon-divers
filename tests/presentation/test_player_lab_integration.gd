extends SceneTree

const _Dungeon3DViewerScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_3d_viewer.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _SemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _LabLeftPanelScript = preload("res://src/dungeon_generator/debug/lab/ui/lab_left_panel.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_player_lab_integration ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "TestWorld"
	get_root().add_child(root)

	# 1. Test Dungeon3DViewer lifecycle
	var viewer = _Dungeon3DViewerScript.new()
	root.add_child(viewer)
	await process_frame

	assert(viewer.is_test_player_enabled() == false, "FAIL: Player should be disabled by default")
	assert(viewer.get_test_player() == null, "FAIL: get_test_player() should be null initially")
	print("  [OK] Initial player state verified: Disabled")

	# 2. Setup mock semantic result with a start room
	var sem := _SemanticResultScript.new()
	var start_room = _RoomDataScript.new(0, Rect2i(10, 15, 6, 8), &"start")
	sem.rooms = [start_room]
	sem.start_room_id = 0
	viewer._current_result = sem

	# 3. Enable test player
	viewer.set_test_player_enabled(true)
	await process_frame

	assert(viewer.is_test_player_enabled() == true, "FAIL: is_test_player_enabled() must be true")
	var player = viewer.get_test_player()
	assert(player != null, "FAIL: Player instance must exist")
	assert(player.is_inside_tree(), "FAIL: Player must be inside the scene tree")
	assert(player is CharacterBody3D, "FAIL: Player must be a CharacterBody3D")

	# Verify spawn position (Center of Rect2i(10, 15, 6, 8) at cell_size 2.0 -> x = (10 + 3) * 2 = 26.0, z = (15 + 4) * 2 = 38.0)
	assert(is_equal_approx(player.position.x, 26.0), "FAIL: Player X spawn position mismatch: %f vs 26.0" % player.position.x)
	assert(is_equal_approx(player.position.z, 38.0), "FAIL: Player Z spawn position mismatch: %f vs 38.0" % player.position.z)
	print("  [OK] Player spawned at correct start room coordinates: (%f, %f)" % [player.position.x, player.position.z])

	# Verify camera targeting
	assert(viewer.camera_rig != null, "FAIL: camera_rig must exist")
	assert(viewer.camera_rig.target == player, "FAIL: camera_rig target must be the player")
	assert(viewer.camera_rig.follow_enabled == true, "FAIL: camera follow must be enabled")
	print("  [OK] Camera rig correctly bound to test player with follow enabled")

	# 4. Disable test player
	viewer.set_test_player_enabled(false)
	await process_frame

	assert(viewer.is_test_player_enabled() == false, "FAIL: Player must be marked disabled")
	assert(viewer.get_test_player() == null, "FAIL: Player reference must be cleared")
	assert(viewer.camera_rig.target == null, "FAIL: Camera target must be cleared")
	print("  [OK] Player cleanup verified: Removed from tree and camera target cleared")

	# 5. Test LabLeftPanel toggle state
	const _PanelScene = preload("res://src/dungeon_generator/debug/lab/ui/lab_left_panel.tscn")
	var panel = _PanelScene.instantiate()
	root.add_child(panel)
	panel._ready()

	panel.set_player_toggle_state(true)
	assert(panel._is_player_module_active == true, "FAIL: Panel player state should be active")
	if panel._player_badge_lbl != null:
		assert(panel._player_badge_lbl.text.find("ACTIVO") != -1, "FAIL: Badge must indicate ACTIVO")

	panel.set_player_toggle_state(false)
	assert(panel._is_player_module_active == false, "FAIL: Panel player state should be inactive")
	if panel._player_badge_lbl != null:
		assert(panel._player_badge_lbl.text.find("INACTIVO") != -1, "FAIL: Badge must indicate INACTIVO")
	print("  [OK] LabLeftPanel toggle state and badge synchronization verified")

	root.free()
	print("\n>>> ALL CHECKS PASSED: PLAYER LAB INTEGRATION FULLY OPERATIONAL! <<<\n")
	quit(0)
