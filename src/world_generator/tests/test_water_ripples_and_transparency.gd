@tool
extends SceneTree

const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

func _init() -> void:
	print("--- Running test_water_ripples_and_transparency ---")

	var profile = _TaigaWorldProfileScript.new()
	var mat = _WaterMaterialScript.create_water_material(profile, true)

	assert(mat is ShaderMaterial, "Material must be a ShaderMaterial")
	var sm: ShaderMaterial = mat as ShaderMaterial

	# 1. Verificar parámetros de transparencia cristalina
	var c_shore = sm.get_shader_parameter("color_shore")
	var c_shallow = sm.get_shader_parameter("color_shallow")
	var c_mid = sm.get_shader_parameter("color_mid")
	var c_deep = sm.get_shader_parameter("color_deep")

	assert(c_shore != null and c_shallow != null and c_mid != null and c_deep != null, "Color uniforms must exist")
	assert(c_shore.a <= 0.50, "Shore color must be translucent (alpha <= 0.50)")
	assert(c_shallow.a <= 0.60, "Shallow color must be translucent (alpha <= 0.60)")
	assert(c_deep.a > c_shallow.a, "Deep water alpha must be deeper/more opaque than shallow")

	# 2. Verificar parámetros de oleaje e interacción (ripples)
	var player_pos = sm.get_shader_parameter("player_pos")
	var player_speed = sm.get_shader_parameter("player_speed")
	var player_in_water = sm.get_shader_parameter("player_in_water")
	var ripples = sm.get_shader_parameter("ripples")

	assert(player_pos != null, "player_pos parameter must exist in shader")
	assert(player_speed != null, "player_speed parameter must exist in shader")
	assert(player_in_water != null, "player_in_water parameter must exist in shader")
	assert(ripples != null and (ripples.size() == 8), "ripples buffer must contain 8 slots")

	# 3. Simular inyección de ondas de pisada
	var test_ripples: Array[Vector4] = []
	for i in range(8):
		test_ripples.append(Vector4(float(i * 2), float(i * 2), 0.25 + float(i) * 0.1, 0.8))
	sm.set_shader_parameter("ripples", test_ripples)
	sm.set_shader_parameter("player_in_water", 1.0)
	sm.set_shader_parameter("player_speed", 4.5)
	sm.set_shader_parameter("player_pos", Vector3(15.0, 2.0, 20.0))

	assert(sm.get_shader_parameter("player_in_water") == 1.0, "player_in_water must update correctly")
	assert(sm.get_shader_parameter("player_speed") == 4.5, "player_speed must update correctly")

	print("[PASS] test_water_ripples_and_transparency completed successfully!")
	quit(0)
