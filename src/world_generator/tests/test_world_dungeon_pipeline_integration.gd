@tool
extends SceneTree

# Test de Integración Integral: World ↔ POI ↔ Dungeon Pipeline
# Valida la cadena causal determinista:
# MasterSeed -> Macro Grid -> DungeonIdentity -> DungeonSeed -> DungeonPipeline

const DungeonIdentity = preload("res://src/world_generator/poi/dungeon_identity.gd")

func _init() -> void:
	print("--- Running World ↔ Dungeon Integration Tests ---")
	var success := true
	
	success = test_task1_identity_and_seeds() and success
	
	if success:
		print("ALL TEST CHECKS PASSED!")
		quit(0)
	else:
		printerr("TEST CHECKS FAILED!")
		quit(1)

func test_task1_identity_and_seeds() -> bool:
	print("\n[Test Task 1] Identity and Seed Derivation...")
	var master_seed := 987654321
	var macro_coord := Vector2i(12, 7)
	var candidate_index := 0
	
	# 1. Verificar derive_dungeon_seed existe en WorldSeedSystem
	var dungeon_id_test: StringName = &"dungeon_m12_7_0"
	var seed_a: int = WorldSeedSystem.derive_dungeon_seed(master_seed, dungeon_id_test)
	var seed_b: int = WorldSeedSystem.derive_dungeon_seed(master_seed, dungeon_id_test)
	if seed_a != seed_b:
		printerr("FAIL: derive_dungeon_seed not deterministic for same inputs")
		return false
	if seed_a == 0:
		printerr("FAIL: derive_dungeon_seed produced 0")
		return false
		
	# 2. Separación de semillas con diferente master_seed o id
	var seed_diff_master: int = WorldSeedSystem.derive_dungeon_seed(12345, dungeon_id_test)
	if seed_diff_master == seed_a:
		printerr("FAIL: Different master_seed produced identical dungeon_seed")
		return false
	var seed_diff_id: int = WorldSeedSystem.derive_dungeon_seed(master_seed, &"dungeon_m12_8_0")
	if seed_diff_id == seed_a:
		printerr("FAIL: Different dungeon_id produced identical dungeon_seed")
		return false
		
	# 3. DungeonIdentity creation
	var identity_1 = DungeonIdentity.create(master_seed, macro_coord, candidate_index)
	if identity_1 == null:
		printerr("FAIL: DungeonIdentity.create returned null")
		return false
	if identity_1.dungeon_id != dungeon_id_test:
		printerr("FAIL: Expected id %s, got %s" % [dungeon_id_test, identity_1.dungeon_id])
		return false
	if identity_1.macro_coord != macro_coord:
		printerr("FAIL: Expected macro_coord %s, got %s" % [macro_coord, identity_1.macro_coord])
		return false
	if identity_1.candidate_index != candidate_index:
		printerr("FAIL: Expected candidate_index %d, got %d" % [candidate_index, identity_1.candidate_index])
		return false
	if identity_1.dungeon_seed != seed_a:
		printerr("FAIL: Expected dungeon_seed %d, got %d" % [seed_a, identity_1.dungeon_seed])
		return false
		
	print("✓ Task 1 identity & seed derivation checks passed.")
	return true
