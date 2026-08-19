extends SceneTree

## Test Suite para Consolidación de Determinismo y Checksums (Fase 4).
## Valida que cada semilla ejecutada N veces produzca exactamente el mismo Checksum SHA-256 (A == B == C)
## y que la derivación de semillas por etapa e intento sea estricta.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

const TEST_SEEDS: Array[int] = [
	1337, 42, 101, 999, 7777, 12345, 54321, 888888, 9999999,
	221533744, 812297351, 649654445, 11223344, 55667788, 99001122,
	314159, 271828, 161803, 100000007, 998244353
]

func _init() -> void:
	print("--- Running test_phase4_determinism ---")
	test_seed_factory_uniqueness()
	test_triple_run_checksum_determinism()
	test_multi_algorithm_determinism()
	print("[PASS] test_phase4_determinism completed successfully!")
	quit(0)

func test_seed_factory_uniqueness() -> void:
	print("  -> Testing DungeonSeedFactory unique stage offsets...")
	var base: int = 123456
	var s_mission := _DungeonSeedFactoryScript.derive_seed(base, 0, &"mission")
	var s_layout := _DungeonSeedFactoryScript.derive_seed(base, 0, &"layout")
	var s_topology := _DungeonSeedFactoryScript.derive_seed(base, 0, &"topology")
	var s_corridor := _DungeonSeedFactoryScript.derive_seed(base, 0, &"corridor")
	var s_door := _DungeonSeedFactoryScript.derive_seed(base, 0, &"door")
	var s_semantics := _DungeonSeedFactoryScript.derive_seed(base, 0, &"semantics")
	
	var seeds: Array[int] = [s_mission, s_layout, s_topology, s_corridor, s_door, s_semantics]
	var unique_seeds: Dictionary = {}
	for s in seeds:
		assert(s != 0, "Derived seed must never be 0")
		unique_seeds[s] = true
	assert(unique_seeds.size() == seeds.size(), "All stage seeds must be strictly distinct")
	print("    [OK] Seed derivation is distinct and deterministic across stages")

func test_triple_run_checksum_determinism() -> void:
	print("  -> Testing 3-run checksum determinism (A == B == C) on %d seeds..." % TEST_SEEDS.size())
	var pipeline := _DungeonPipelineScript.new()
	
	for seed_val in TEST_SEEDS:
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res_a = pipeline.generate(config, 5, true)
		var res_b = pipeline.generate(config, 5, true)
		var res_c = pipeline.generate(config, 5, true)
		
		assert(res_a != null and res_b != null and res_c != null, "Generation must succeed for seed %d" % seed_val)
		assert(res_a.checksum != "", "Checksum must not be empty")
		assert(res_a.checksum == res_b.checksum, "Run A and B must match for seed %d (got %s vs %s)" % [seed_val, res_a.checksum, res_b.checksum])
		assert(res_b.checksum == res_c.checksum, "Run B and C must match for seed %d (got %s vs %s)" % [seed_val, res_b.checksum, res_c.checksum])
		assert(res_a.rooms.size() == res_b.rooms.size(), "Room count must be identical")
		assert(res_a.connections.size() == res_b.connections.size(), "Connection count must be identical")
		assert(res_a.doors.size() == res_b.doors.size(), "Door count must be identical")
	
	print("    [OK] All %d seeds passed triple checksum verification (A == B == C)" % TEST_SEEDS.size())

func test_multi_algorithm_determinism() -> void:
	print("  -> Testing determinism across different algorithms (CellularAutomata, BSP, Hybrid)...")
	var pipeline := _DungeonPipelineScript.new()
	var algorithms: Array[String] = ["CellularAutomata", "BSP", "Hybrid"]
	
	for alg in algorithms:
		var config := _DungeonConfigScript.new()
		config.seed = 649654445
		config.use_fixed_seed = true
		config.algorithm = alg
		
		var res_1 = pipeline.generate(config, 5, true)
		var res_2 = pipeline.generate(config, 5, true)
		
		assert(res_1 != null and res_2 != null, "Algorithm %s must succeed" % alg)
		assert(res_1.checksum == res_2.checksum, "Algorithm %s must produce identical checksums" % alg)
	
	print("    [OK] All generation algorithms verified 100% deterministic")
