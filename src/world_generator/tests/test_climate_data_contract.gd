extends SceneTree

const WorldSeedSystemScript = preload("res://src/world_generator/data/world_seed_system.gd")
const WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Climate & Biome Data Contract Test (Fase 1)")
	print("==================================================")

	# 1. Verificación de DOMAIN_CLIMATE en WorldSeedSystem
	assert(WorldSeedSystem.DOMAIN_CLIMATE == "climate", "DOMAIN_CLIMATE must be 'climate'")

	var seed_terrain = WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var seed_climate = WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_CLIMATE)
	var seed_climate_dup = WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_CLIMATE)

	assert(seed_climate == seed_climate_dup, "Climate seed derivation must be strictly deterministic")
	assert(seed_climate != seed_terrain, "Climate seed must be isolated from terrain seed domain")
	print(" -> [PASS] DOMAIN_CLIMATE isolation & determinism")

	# 2. Verificación de campos en WorldCell
	var cell: WorldCell = WorldCellScript.new(Vector2i(5, 10))
	assert(cell.position == Vector2i(5, 10), "Cell position preserved")
	assert(cell.temperature == 0.5, "Default temperature must be 0.5")
	assert(cell.moisture == 0.5, "Default moisture must be 0.5")
	assert(cell.biome_id == &"taiga", "Default biome_id must be 'taiga' for backward compatibility")
	print(" -> [PASS] WorldCell default climate & biome fields")

	# 3. Verificación de elevación normalizada [0..1]
	cell.normalized_height = 0.72
	assert(is_equal_approx(cell.elevation_normalized, 0.72), "elevation_normalized getter must mirror normalized_height")
	cell.elevation_normalized = 0.35
	assert(is_equal_approx(cell.normalized_height, 0.35), "elevation_normalized setter must mirror normalized_height")
	print(" -> [PASS] WorldCell elevation_normalized alias accessor")

	print("==================================================")
	print(" ALL FASE 1 CLIMATE DATA CONTRACT TESTS PASSED!")
	print("==================================================")
	quit(0)
