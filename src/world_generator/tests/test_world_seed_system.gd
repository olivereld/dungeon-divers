extends SceneTree

func _init() -> void:
	var seed_1 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var seed_2 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 == seed_2, "Same master seed and domain must produce identical child seed")

	var seed_eco := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_ECOLOGY)
	assert(seed_1 != seed_eco, "Different domains must produce distinct seeds")

	var seed_other_master := WorldSeedSystem.derive_seed(99999, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 != seed_other_master, "Different master seeds must produce distinct child seeds")

	print("test_world_seed_system: OK")
	quit()
