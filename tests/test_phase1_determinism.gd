extends SceneTree

func _init() -> void:
	print("--- Running test_phase1_determinism ---")
	var pipeline := DungeonPipeline.new()
	assert(DungeonPipeline.MAX_ATTEMPTS == 5, "MAX_ATTEMPTS must be 5")

	var test_seeds: Array[int] = [12345, 987654321, 55555, 42, 888123]

	for test_seed in test_seeds:
		var config1 := DungeonConfig.new()
		config1.seed = test_seed
		config1.use_fixed_seed = true

		var config2 := DungeonConfig.new()
		config2.seed = test_seed
		config2.use_fixed_seed = true

		var res1 = pipeline.generate(config1, 5, true)
		var res2 = pipeline.generate(config2, 5, true)

		assert(res1 != null, "Generation 1 must succeed for seed %d" % test_seed)
		assert(res2 != null, "Generation 2 must succeed for seed %d" % test_seed)

		# 1. Verificar Semilla
		assert(res1.seed_used == res2.seed_used, "Seed used must match")

		# 2. Verificar Fitness
		assert(is_equal_approx(res1.fitness_score, res2.fitness_score), "Fitness must be identical")

		# 3. Verificar Habitaciones (cantidad, rectángulos y tipos)
		assert(res1.rooms.size() == res2.rooms.size(), "Room count must be identical")
		for i in range(res1.rooms.size()):
			var r1: RoomData = res1.rooms[i]
			var r2: RoomData = res2.rooms[i]
			assert(r1.id == r2.id, "Room ID must match at %d" % i)
			assert(r1.rect == r2.rect, "Room rect must match at %d" % i)
			assert(r1.room_type == r2.room_type, "Room type must match at %d" % i)

		# 4. Verificar CellGrid celda por celda
		assert(res1.grid.width == res2.grid.width, "Grid width must match")
		assert(res1.grid.height == res2.grid.height, "Grid height must match")
		for y in range(res1.grid.height):
			for x in range(res1.grid.width):
				var p := Vector2i(x, y)
				var c1: CellGrid.CellType = res1.grid.get_cell(p)
				var c2: CellGrid.CellType = res2.grid.get_cell(p)
				assert(c1 == c2, "Cell at (%d, %d) mismatch: %d vs %d" % [x, y, c1, c2])

		print("  [OK] Determinism verified for seed %d: 100%% identical (Rooms: %d, Fitness: %.4f)" % [
			test_seed, res1.rooms.size(), res1.fitness_score
		])

	# 5. Verificar derivación determinista de DungeonSeedFactory
	var seed_factory = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
	var s_mission_1: int = seed_factory.derive_seed(100, 0, &"mission")
	var s_mission_2: int = seed_factory.derive_seed(100, 0, &"mission")
	var s_layout: int = seed_factory.derive_seed(100, 0, &"layout")
	assert(s_mission_1 == s_mission_2, "Same parameters must derive same seed")
	assert(s_mission_1 != s_layout, "Different stages must derive distinct seeds")

	print("[PASS] test_phase1_determinism succeeded: Absolute determinism guaranteed across all stages.")
	quit(0)
