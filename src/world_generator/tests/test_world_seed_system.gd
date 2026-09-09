extends SceneTree

func _init() -> void:
	var seed_1 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var seed_2 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 == seed_2, "Same master seed and domain must produce identical child seed")

	var seed_eco := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_ECOLOGY)
	assert(seed_1 != seed_eco, "Different domains must produce distinct seeds")

	var seed_other_master := WorldSeedSystem.derive_seed(99999, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 != seed_other_master, "Different master seeds must produce distinct child seeds")

	# POI seed tests
	var poi_seed_1 := WorldSeedSystem.derive_poi_seed(12345, &"campsite_1", Vector2i(10, 20), &"taiga_camp")
	var poi_seed_1_dup := WorldSeedSystem.derive_poi_seed(12345, &"campsite_1", Vector2i(10, 20), &"taiga_camp")
	assert(poi_seed_1 == poi_seed_1_dup, "Identical POI parameters must yield identical seeds")

	var poi_seed_diff_pos := WorldSeedSystem.derive_poi_seed(12345, &"campsite_1", Vector2i(11, 20), &"taiga_camp")
	assert(poi_seed_1 != poi_seed_diff_pos, "Different POI positions must yield distinct seeds")

	var poi_seed_diff_arch := WorldSeedSystem.derive_poi_seed(12345, &"campsite_1", Vector2i(10, 20), &"taiga_ruins")
	assert(poi_seed_1 != poi_seed_diff_arch, "Different POI archetypes must yield distinct seeds")

	print("test_world_seed_system: OK")
	quit()
