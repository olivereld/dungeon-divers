extends SceneTree

func _init() -> void:
	print("--- Running test_camera_view_toggle ---")
	var scene_res = load("res://scenes/dungeon/dungeon_level.tscn")
	var instance: DungeonLevelController = scene_res.instantiate()
	root.add_child(instance)

	assert(instance.camera != null, "Camera must exist")

	# Initial mode should be isometric
	assert(instance._is_top_down == false, "Initial camera should be Isometric")
	assert(instance.camera.rotation_degrees.is_equal_approx(Vector3(-45, 45, 0)), "Isometric rotation must be (-45, 45, 0)")

	# Simulate pressing T/V to toggle view
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_T
	instance._input(event)

	assert(instance._is_top_down == true, "Camera should now be in Top-Down mode")
	assert(instance.camera.rotation_degrees.is_equal_approx(Vector3(-90, 0, 0)), "Top-Down rotation must be (-90, 0, 0)")
	print("Top-down camera position: ", instance.camera.position, " rotation: ", instance.camera.rotation_degrees)

	# Toggle back to isometric
	event.keycode = KEY_V
	instance._input(event)

	assert(instance._is_top_down == false, "Camera should toggle back to Isometric mode")
	assert(instance.camera.rotation_degrees.is_equal_approx(Vector3(-45, 45, 0)), "Isometric rotation restored")
	print("Isometric camera position: ", instance.camera.position, " rotation: ", instance.camera.rotation_degrees)

	instance.queue_free()
	print("[PASS] test_camera_view_toggle succeeded.")
	quit(0)
