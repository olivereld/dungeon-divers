class_name TestBiomeProfile
extends SceneTree

const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_biome_profile ---")

	# Test 1: Instanciación y defaults
	var profile = _BiomeProfileScript.new()
	assert(profile.floor_index == 0, "floor_index default should be 0")
	assert(profile.wall_index == 1, "wall_index default should be 1")
	print("  [OK] Test 1: BiomeProfile instantiates with valid defaults")

	# Test 2: Validación sin MeshLibrary en modo producción -> FATAL MISSING_MESH_LIBRARY
	var diags_no_lib: Array[Dictionary] = profile.validate_profile(false)
	assert(diags_no_lib.size() == 1, "Should have 1 fatal diagnostic for missing mesh library")
	assert(diags_no_lib[0]["code"] == "MISSING_MESH_LIBRARY", "Code should be MISSING_MESH_LIBRARY")
	assert(diags_no_lib[0]["severity"] == "FATAL", "Severity should be FATAL")
	print("  [OK] Test 2: Missing MeshLibrary in production produces FATAL diagnostic")

	# Test 3: Validación con MeshLibrary que tiene índices faltantes -> ERROR INVALID_TILE_MAPPING
	var mock_lib := MeshLibrary.new()
	mock_lib.create_item(0) # Solo creamos floor_index 0, dejamos wall_index 1 sin crear
	profile.mesh_library = mock_lib

	var diags_invalid: Array[Dictionary] = profile.validate_profile(false)
	assert(diags_invalid.size() == 1, "Should have 1 error for missing wall_index")
	assert(diags_invalid[0]["code"] == "INVALID_TILE_MAPPING", "Code should be INVALID_TILE_MAPPING")
	assert(diags_invalid[0]["severity"] == "ERROR", "Severity should be ERROR")
	print("  [OK] Test 3: Incomplete MeshLibrary mappings produce ERROR diagnostic")

	# Test 4: Validación con MeshLibrary completa -> 0 diagnósticos bloqueantes
	mock_lib.create_item(1) # Ahora creamos wall_index 1
	var diags_valid: Array[Dictionary] = profile.validate_profile(false)
	assert(diags_valid.is_empty(), "Valid MeshLibrary should produce 0 diagnostics")
	print("  [OK] Test 4: Complete MeshLibrary passes validation with 0 errors")

	print("[PASS] test_biome_profile succeeded with 100% assertions passing!")
	quit(0)
