extends SceneTree

const WallFadeControllerScript = preload("res://src/presentation/camera/wall_fade_controller.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_wall_fade_controller ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "FadeTestWorld"
	get_root().add_child(root)

	var fader = WallFadeControllerScript.new()
	fader.occluded_transparency = 0.75
	fader.fade_speed = 12.0
	root.add_child(fader)

	var wall_a := MeshInstance3D.new()
	wall_a.name = "Wall_A"
	root.add_child(wall_a)

	var wall_b := MeshInstance3D.new()
	wall_b.name = "Wall_B"
	root.add_child(wall_b)

	await process_frame

	assert(is_equal_approx(wall_a.transparency, 0.0), "FAIL: Initial transparency of Wall A should be 0.0")
	assert(is_equal_approx(wall_b.transparency, 0.0), "FAIL: Initial transparency of Wall B should be 0.0")

	# 1. Fade Out en Wall A y Wall B
	fader.fade_out([wall_a, wall_b])
	assert(fader.get_tracked_walls_count() == 2, "FAIL: Fader should track 2 walls")

	# Simular 1 paso de fade
	fader.process_fade_step(0.05)
	assert(wall_a.transparency > 0.0 and wall_a.transparency < 0.75, "FAIL: Wall A should be smoothly interpolating toward 0.75")
	assert(wall_b.transparency > 0.0 and wall_b.transparency < 0.75, "FAIL: Wall B should be smoothly interpolating toward 0.75")

	# Simular convergencia completa
	for _i in range(120):
		fader.process_fade_step(0.05)

	assert(is_equal_approx(wall_a.transparency, 0.75), "FAIL: Wall A should converge to 0.75")
	assert(is_equal_approx(wall_b.transparency, 0.75), "FAIL: Wall B should converge to 0.75")

	# 2. Liberar Wall A (fade_in) manteniendo Wall B ocluido
	fader.fade_in([wall_a])

	for _i in range(120):
		fader.process_fade_step(0.05)

	assert(is_equal_approx(wall_a.transparency, 0.0), "FAIL: Wall A should restore to 0.0 (opaque)")
	assert(is_equal_approx(wall_b.transparency, 0.75), "FAIL: Wall B must remain at 0.75 (occluded)")

	# 3. Liberar Wall B
	fader.fade_in([wall_b])
	for _i in range(120):
		fader.process_fade_step(0.05)

	assert(is_equal_approx(wall_b.transparency, 0.0), "FAIL: Wall B should restore to 0.0")
	assert(fader.get_tracked_walls_count() == 0, "FAIL: No walls should be tracked after full fade in")

	root.free()

	print("[PASS] test_wall_fade_controller completed successfully.")
	quit(0)
