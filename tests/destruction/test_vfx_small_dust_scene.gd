extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_vfx_small_dust_scene (Task 1) ---")
	print("==================================================================")
	var scn = load("res://scenes/vfx/destruction/vfx_small_dust.tscn") as PackedScene
	assert(scn != null, "FAIL: vfx_small_dust.tscn failed to load")

	var instance = scn.instantiate()
	assert(instance is _VFXInstanceScript, "FAIL: root must be VFXInstance")
	assert(instance.max_lifetime <= 1.0, "FAIL: max_lifetime should be around 0.9s")
	assert(instance.auto_cleanup == true, "FAIL: auto_cleanup must be true")

	# 1. Validar las 4 capas especializadas
	var burst = instance.get_node_or_null("DustBurst")
	assert(burst != null, "FAIL: DustBurst node missing")
	assert(burst is CPUParticles3D, "FAIL: DustBurst must be CPUParticles3D")
	assert(burst.one_shot == true, "FAIL: DustBurst must be one_shot")

	var cloud = instance.get_node_or_null("DustCloud")
	assert(cloud != null, "FAIL: DustCloud node missing")
	assert(cloud is CPUParticles3D, "FAIL: DustCloud must be CPUParticles3D")
	assert(cloud.one_shot == true, "FAIL: DustCloud must be one_shot")

	var debris = instance.get_node_or_null("Debris")
	assert(debris != null, "FAIL: Debris node missing")
	assert(debris is CPUParticles3D, "FAIL: Debris must be CPUParticles3D")
	assert(debris.one_shot == true, "FAIL: Debris must be one_shot")

	var ground = instance.get_node_or_null("GroundDust")
	assert(ground != null, "FAIL: GroundDust node missing")
	assert(ground is CPUParticles3D, "FAIL: GroundDust must be CPUParticles3D")
	assert(ground.one_shot == true, "FAIL: GroundDust must be one_shot")

	instance.free()
	print("[PASS] test_vfx_small_dust_scene passed 100%!")
	print("==================================================================")
	quit(0)
