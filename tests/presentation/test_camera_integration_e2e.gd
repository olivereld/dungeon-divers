extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const PlayerTestScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_integration_e2e ---")
	print("==================================================================")

	var root := Node3D.new()
	get_root().add_child(root)

	var rig = IsometricCameraRigScript.new()
	var player = PlayerTestScript.new()

	root.add_child(rig)
	root.add_child(player)

	player.position = Vector3(14.0, 0.0, 14.0)
	rig.set_target(player)
	rig.teleport_to_target()

	assert(is_equal_approx(rig.global_position.x, 14.0), "FAIL: Rig should be positioned at player X")
	assert(is_equal_approx(rig.global_position.z, 14.0), "FAIL: Rig should be positioned at player Z")

	# Test Zoom In / Zoom Out API
	var initial_zoom: float = rig.get_zoom()
	rig.zoom_in()
	assert(rig.target_zoom < initial_zoom, "FAIL: zoom_in should decrease orthogonal size")

	rig.zoom_out()
	assert(is_equal_approx(rig.target_zoom, initial_zoom), "FAIL: zoom_out should restore orthogonal size")

	root.free()

	print("[PASS] test_camera_integration_e2e completed successfully.")
	quit(0)
