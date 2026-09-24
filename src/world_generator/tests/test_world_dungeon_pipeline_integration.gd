@tool
extends SceneTree

# Test de Integración Integral: World ↔ POI ↔ Dungeon Pipeline
# Valida la cadena causal determinista:
# MasterSeed -> Macro Grid -> DungeonIdentity -> DungeonSeed -> DungeonPipeline

const DungeonIdentity = preload("res://src/world_generator/poi/dungeon_identity.gd")

const DungeonPOI = preload("res://src/world_generator/poi/dungeon_poi.gd")
const DungeonPOIGenerator = preload("res://src/world_generator/poi/dungeon_poi_generator.gd")

func _init() -> void:
	print("--- Running World ↔ Dungeon Integration Tests ---")
	var success := true
	
	success = test_task1_identity_and_seeds() and success
	success = test_task2_dungeon_poi() and success
	success = test_task3_poi_generator() and success
	
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

func test_task2_dungeon_poi() -> bool:
	print("\n[Test Task 2] DungeonPOI Entity...")
	var master_seed := 987654321
	var macro_coord := Vector2i(4, 8)
	var identity = DungeonIdentity.create(master_seed, macro_coord, 0)
	
	var poi = DungeonPOI.new()
	poi.identity = identity
	poi.world_position = Vector3(1030.5, 45.0, 2050.2)
	poi.entrance_transform = Transform3D(Basis(), poi.world_position)
	poi.archetype_id = &"catacombs"
	poi.tier = 2
	poi.total_floors = 3
	poi.orientation_deg = 180.0
	poi.bounding_rect = Rect2i(1020, 2040, 20, 20)
	
	# Verificar campos
	if poi.identity.dungeon_id != &"dungeon_m4_8_0":
		printerr("FAIL: poi.identity mismatch")
		return false
	if poi.tier != 2 or poi.total_floors != 3 or poi.archetype_id != &"catacombs":
		printerr("FAIL: poi property mismatch")
		return false
		
	# Verificar desacoplamiento de chunk_coord: get_chunk_coord(16)
	var expected_chunk := Vector2i(int(floor(1030.5 / 16.0)), int(floor(2050.2 / 16.0)))
	var calculated_chunk: Vector2i = poi.get_chunk_coord(16)
	if calculated_chunk != expected_chunk:
		printerr("FAIL: Expected chunk %s, got %s" % [expected_chunk, calculated_chunk])
		return false
		
	print("✓ Task 2 DungeonPOI checks passed.")
	return true

# Mock World Query que no genera chunks, sino que simula respuestas del terreno
class MockWorldQuery extends RefCounted:
	var water_at: Array[Vector2i] = []
	var steep_at: Array[Vector2i] = []
	var biome_override: StringName = &"forest"
	
	func get_elevation(x: int, z: int) -> float:
		return 35.0
	
	func get_slope(x: int, z: int) -> float:
		if Vector2i(x, z) in steep_at:
			return 45.0 # demasiado empinado
		return 8.0 # pendiente suave
		
	func is_water(x: int, z: int) -> bool:
		return Vector2i(x, z) in water_at
		
	func get_biome(x: int, z: int) -> StringName:
		return biome_override

func test_task3_poi_generator() -> bool:
	print("\n[Test Task 3] DungeonPOIGenerator...")
	var master_seed := 1337
	var macro_coord := Vector2i(3, 5)
	var generator = DungeonPOIGenerator.new(256, 32, 100.0)
	
	# 1. Determinismo en candidato de macro-celda
	var cand_a = generator.generate_candidate_for_macro_cell(master_seed, macro_coord, 0)
	var cand_b = generator.generate_candidate_for_macro_cell(master_seed, macro_coord, 0)
	if cand_a["world_x"] != cand_b["world_x"] or cand_a["world_z"] != cand_b["world_z"]:
		printerr("FAIL: Candidate position is not deterministic")
		return false
	
	# Verificar que cae dentro de los límites y márgenes de la celda
	var min_x := macro_coord.x * 256 + 32
	var max_x := (macro_coord.x + 1) * 256 - 32
	if cand_a["world_x"] < min_x or cand_a["world_x"] > max_x:
		printerr("FAIL: Candidate x %d out of bounds [%d, %d]" % [cand_a["world_x"], min_x, max_x])
		return false
		
	# 2. Evaluación ambiental válida
	var query := MockWorldQuery.new()
	var poi: DungeonPOI = generator.evaluate_and_create_poi(master_seed, macro_coord, query)
	if poi == null:
		printerr("FAIL: Valid candidate was rejected")
		return false
	if poi.identity.macro_coord != macro_coord:
		printerr("FAIL: POI macro_coord mismatch")
		return false
	if poi.archetype_id != &"ruins": # en bosque -> ruins
		printerr("FAIL: Expected archetype 'ruins' for forest, got %s" % [poi.archetype_id])
		return false
		
	# 3. Rechazo por agua
	var water_query := MockWorldQuery.new()
	water_query.water_at.append(Vector2i(cand_a["world_x"], cand_a["world_z"]))
	var poi_water: DungeonPOI = generator.evaluate_and_create_poi(master_seed, macro_coord, water_query)
	if poi_water != null:
		printerr("FAIL: Candidate on water should have been rejected")
		return false
		
	# 4. Rechazo por pendiente excesiva
	var steep_query := MockWorldQuery.new()
	steep_query.steep_at.append(Vector2i(cand_a["world_x"], cand_a["world_z"]))
	var poi_steep: DungeonPOI = generator.evaluate_and_create_poi(master_seed, macro_coord, steep_query)
	if poi_steep != null:
		printerr("FAIL: Candidate on steep slope should have been rejected")
		return false
		
	print("✓ Task 3 DungeonPOIGenerator checks passed.")
	return true
