extends SceneTree

func _init() -> void:
	print("--- Running test_pipeline_integration ---")
	var pipeline := DungeonPipeline.new()

	# 1. Test 32x32 CA
	var config_32 := DungeonConfig.new()
	config_32.grid_width = 32
	config_32.grid_height = 32
	config_32.algorithm = "CellularAutomata"
	config_32.mission_depth = 4

	var res_32: DungeonPipeline.DungeonResult = pipeline.generate(config_32)
	assert(res_32 != null, "Pipeline 32x32 CA should generate result")
	assert(res_32.grid.width == 32 and res_32.grid.height == 32, "Grid dimensions should be 32x32")
	assert(res_32.validation.is_winnable, "32x32 dungeon must be winnable")
	print("-> 32x32 CA generated in %.2f ms, rooms: %d, fitness: %.2f" % [
		res_32.generation_time_ms, res_32.rooms.size(), res_32.fitness_score
	])

	# 2. Test 64x64 Hybrid
	var config_64 := DungeonConfig.new()
	config_64.grid_width = 64
	config_64.grid_height = 64
	config_64.algorithm = "Hybrid"
	config_64.mission_depth = 6

	var res_64: DungeonPipeline.DungeonResult = pipeline.generate(config_64)
	assert(res_64 != null, "Pipeline 64x64 Hybrid should generate result")
	assert(res_64.grid.width == 64 and res_64.grid.height == 64, "Grid dimensions should be 64x64")
	assert(res_64.validation.is_winnable, "64x64 dungeon must be winnable")
	print("-> 64x64 Hybrid generated in %.2f ms, rooms: %d, fitness: %.2f" % [
		res_64.generation_time_ms, res_64.rooms.size(), res_64.fitness_score
	])

	# 3. Test Multi-piso seed consistency
	var config_floor1 := DungeonConfig.new()
	config_floor1.dungeon_id = &"crypt_alpha"
	config_floor1.floor_number = 1
	config_floor1.seed = 4242

	var res_f1_a := pipeline.generate(config_floor1)
	var res_f1_b := pipeline.generate(config_floor1)
	assert(res_f1_a.seed_used == res_f1_b.seed_used, "Same floor must reuse identical seed for consistency")

	var config_floor2 := DungeonConfig.new()
	config_floor2.dungeon_id = &"crypt_alpha"
	config_floor2.floor_number = 2
	config_floor2.seed = 4242

	var res_f2 := pipeline.generate(config_floor2)
	assert(res_f1_a.seed_used != res_f2.seed_used, "Floor 2 must have distinct deterministic seed from Floor 1")

	print("[PASS] test_pipeline_integration succeeded.")
	quit(0)
