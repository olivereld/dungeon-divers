extends SceneTree

const _TerrainMatScript = preload("res://src/world_generator/presentation/terrain_material.gd")

func _init() -> void:
	print("Running test_terrain_corruption_material...")
	var mat = _TerrainMatScript.create_material(null, true) as ShaderMaterial
	assert(mat != null, "Material must be ShaderMaterial")
	
	# Verify corrupted and funeral textures are loaded
	var corrupted_tex = mat.get_shader_parameter("corrupted_ground_texture")
	assert(corrupted_tex != null, "corrupted_ground_texture must be set on material")
	var funeral_tex = mat.get_shader_parameter("funeral_ground_texture")
	assert(funeral_tex != null, "funeral_ground_texture must be set on material")
	
	# Verify corrupted cliff textures are loaded
	var cliff_cor1 = mat.get_shader_parameter("cliff_corrupted_texture")
	assert(cliff_cor1 != null, "cliff_corrupted_texture must be set on material")
	var cliff_cor2 = mat.get_shader_parameter("cliff_corrupted_secondary_texture")
	assert(cliff_cor2 != null, "cliff_corrupted_secondary_texture must be set on material")

	print("[PASS] test_terrain_corruption_material")
	quit(0)
