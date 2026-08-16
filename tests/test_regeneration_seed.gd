extends SceneTree

func _init() -> void:
	print("--- Running test_regeneration_seed ---")
	var pipeline := DungeonPipeline.new()

	var cfg := DungeonConfig.new()
	cfg.dungeon_id = &"test_dungeon"
	cfg.floor_number = 1

	# Primera generación
	var res1 := pipeline.generate(cfg, 5, false)
	assert(res1 != null, "Res1 must not be null")
	var seed1: int = res1.seed_used

	# Segunda generación normal (misma mazmorra / consistencia de piso al volver)
	var res2 := pipeline.generate(cfg, 5, false)
	assert(res2.seed_used == seed1, "Normal re-entry must reuse identical seed for consistency")

	# Tercera generación forzando nueva semilla (como al presionar R o Espacio)
	var res3 := pipeline.generate(cfg, 5, true)
	assert(res3.seed_used != seed1, "Force new seed (R/Space) must produce a different seed")

	# Cuarta generación forzando otra nueva semilla
	var res4 := pipeline.generate(cfg, 5, true)
	assert(res4.seed_used != res3.seed_used, "Successive force new seed must produce another distinct seed")

	print("Seed 1: %d | Seed 2 (same floor): %d | Seed 3 (R/Space): %d | Seed 4 (R/Space): %d" % [
		seed1, res2.seed_used, res3.seed_used, res4.seed_used
	])
	print("[PASS] test_regeneration_seed succeeded.")
	quit(0)
