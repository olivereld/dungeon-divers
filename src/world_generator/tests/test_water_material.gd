extends SceneTree

const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("--- Test WaterMaterial ---")
	var profile = _TaigaWorldProfileScript.new()
	var mat_standard = _WaterMaterialScript.create_water_material(profile, false)
	assert(mat_standard is StandardMaterial3D, "Standard material fallback must exist")

	var mat_shader = _WaterMaterialScript.create_water_material(profile, true)
	assert(mat_shader is ShaderMaterial, "Shader material must be created")
	print("Test WaterMaterial: PASSED")
	quit(0)
