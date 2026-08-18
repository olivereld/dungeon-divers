extends SceneTree

## Suite de pruebas unitarias para PR-10C: SeedDerivation Canónica Versionada (v1).

func _init() -> void:
	print("--- Running test_seed_derivation (PR-10C) ---")

	var seed_derivation_script = preload("res://src/dungeon_generator/core/seed_derivation.gd")
	var master_seed: int = 133742

	# 1. Validar Determinismo Estricto
	var s1 = seed_derivation_script.derive_floor_seed(master_seed, 0)
	var s2 = seed_derivation_script.derive_floor_seed(master_seed, 0)
	assert(s1 == s2, "Derived seeds with identical inputs must be bit-identical")
	assert(s1 >= 0 and s1 <= 0x7FFFFFFF, "Derived seed must be within positive 31-bit integer range")
	print("  [OK] Bit-level determinism verified")

	# 2. Validar Aislamiento por Índice de Piso
	var s_floor_0 = seed_derivation_script.derive_floor_seed(master_seed, 0)
	var s_floor_1 = seed_derivation_script.derive_floor_seed(master_seed, 1)
	var s_floor_2 = seed_derivation_script.derive_floor_seed(master_seed, 2)
	assert(s_floor_0 != s_floor_1 and s_floor_1 != s_floor_2 and s_floor_0 != s_floor_2, "Different floors must yield distinct seeds")
	print("  [OK] Floor index isolation verified")

	# 3. Validar Aislamiento por Dominio en el Mismo Piso
	var s_core = seed_derivation_script.derive_floor_seed(master_seed, 1)
	var s_sem = seed_derivation_script.derive_semantic_seed(master_seed, 1)
	var s_stairs = seed_derivation_script.derive_stairs_seed(master_seed, 1)
	var s_wall = seed_derivation_script.derive_wall_mesh_seed(master_seed, 1)
	assert(s_core != s_sem and s_sem != s_stairs and s_stairs != s_wall and s_core != s_stairs, "Different domains must yield distinct seeds")
	print("  [OK] Cross-domain isolation verified (core, semantic, stairs, wall_mesh)")

	# 4. Validar Generación de Traza de Semillas (Seed Trace)
	var trace: Dictionary = seed_derivation_script.build_multi_floor_seed_trace(master_seed, [0, 1, 2])
	assert(trace["version"] == "v1", "Trace version must be v1")
	assert(trace["master_seed"] == master_seed, "Master seed must match")
	assert(trace["floors"].size() == 3, "Trace must contain all 3 floors")
	assert(trace["floors"][0]["core_seed"] == s_floor_0, "Trace core seed must match derived seed")
	print("  [OK] Multi-floor seed trace schema and audit trail verified")

	print("\n>>> ALL PR-10C SEED DERIVATION TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
