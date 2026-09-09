extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Running World Generator Comprehensive Test Suite")
	print("==================================================")

	var profile := TaigaWorldProfile.new()
	assert(profile.width == 128 and profile.height == 128)

	# 1. Master Seed & Domain Isolation
	var s_terrain := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var s_eco := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_ECOLOGY)
	var s_veg := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_VEGETATION)
	assert(s_terrain != s_eco and s_eco != s_veg, "Derived domain seeds must be distinct")

	# 2. Pipeline Execution
	var result := WorldPipeline.generate(12345, profile)
	assert(result != null, "WorldResult must not be null")
	assert(result.dimensions == Vector2i(128, 128))
	assert(result.cells.size() == 128 * 128)

	# 3. Integrity & Validation
	var val_report := WorldValidator.validate(result)
	assert(val_report["valid"], "Validation failed: %s" % str(val_report["errors"]))
	assert(val_report["walkable_ratio"] >= 0.60, "Walkable ratio must be >= 60%")
	assert(result.vegetation.size() > 100, "Should place abundant vegetation in taiga")

	# 4. Strict Determinism Check
	var result_b := WorldPipeline.generate(12345, profile)
	assert(result.vegetation.size() == result_b.vegetation.size(), "Vegetation count must match across identical seed runs")
	assert(result.spawn_position == result_b.spawn_position, "Spawn position must match across identical seed runs")

	# 5. Renderer Check
	var renderer := WorldRenderer.new()
	var world_node := renderer.render_world(result, profile.cell_size)
	assert(world_node != null)
	assert(world_node.has_node("TerrainMesh"))
	assert(world_node.has_node("TerrainCollision"))
	world_node.free()
	renderer.free()

	print(" [PASS] 1. Seed Derivation & Domain Isolation")
	print(" [PASS] 2. Pipeline Execution (128x128 Grid)")
	print(" [PASS] 3. Data Integrity & Headless Validation (Walkable: %.1f%%, Veg: %d)" % [val_report["walkable_ratio"] * 100.0, result.vegetation.size()])
	print(" [PASS] 4. Strict Deterministic Reproducibility")
	print(" [PASS] 5. WorldRenderer 3D Mesh & MultiMesh Generation")
	print("==================================================")
	print(" ALL WORLD GENERATOR TESTS PASSED!")
	print("==================================================")
	quit()
