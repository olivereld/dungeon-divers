extends SceneTree

const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _FoliageMaterialScript = preload("res://src/world_generator/foliage/rendering/foliage_material.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Foliage Shader & Material Test (Tarea 3)")
	print("==================================================")

	var species = _FoliageSpeciesScript.new(
		&"grass_large",
		"Large Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		1.0,
		Vector3.ONE,
		Vector3.ONE,
		25.0,
		Color(0.2, 0.3, 0.15),
		Color(0.6, 0.8, 0.4)
	)

	var mat1 = _FoliageMaterialScript.get_or_create_material(species, 0.4, 2.5)
	assert(mat1 != null, "ShaderMaterial must be created")
	assert(mat1 is ShaderMaterial, "Must be ShaderMaterial")
	assert(mat1.shader != null, "Shader must be assigned")

	var tex = mat1.get_shader_parameter("texture_albedo")
	assert(tex != null, "Texture albedo parameter must be set")
	assert(mat1.get_shader_parameter("wind_strength") == 0.4, "Wind strength must match")
	assert(mat1.get_shader_parameter("wind_speed") == 2.5, "Wind speed must match")

	# Test caching
	var mat2 = _FoliageMaterialScript.get_or_create_material(species, 0.4, 2.5)
	assert(mat1 == mat2, "Same parameters must return cached material")
	print(" -> [PASS] Foliage shader and material cache verified")

	print("==================================================")
	print(" ALL FOLIAGE SHADER & MATERIAL TESTS PASSED!")
	print("==================================================")
	quit(0)
