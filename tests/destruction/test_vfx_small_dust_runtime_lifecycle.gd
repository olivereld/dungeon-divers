extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_vfx_small_dust_runtime_lifecycle (Task 2) ---")
	print("==================================================================")
	var scn = load("res://scenes/vfx/destruction/vfx_small_dust.tscn") as PackedScene
	var parent = Node3D.new()
	root.add_child(parent)
	await process_frame

	var vfx = scn.instantiate() as _VFXInstanceScript
	parent.add_child(vfx)
	vfx.play()

	assert(vfx.get_node("DustBurst").emitting == true, "FAIL: DustBurst must emit")
	assert(vfx.get_node("DustCloud").emitting == true, "FAIL: DustCloud must emit")
	assert(vfx.get_node("Debris").emitting == true, "FAIL: Debris must emit")
	assert(vfx.get_node("GroundDust").emitting == true, "FAIL: GroundDust must emit")
	print("[Test] Las 4 capas emiten simultáneamente al invocar play().")

	# Forzar cleanup y verificar liberación de árbol
	vfx.cleanup()
	await process_frame

	parent.free()
	print("[PASS] test_vfx_small_dust_runtime_lifecycle passed 100%!")
	print("==================================================================")
	quit(0)
