extends SceneTree

const DungeonLightingGenerator = preload("res://src/dungeon_lighting/facade/dungeon_lighting_generator.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lighting_determinism ---")
	print("==================================================================")

	var d_cfg := DungeonConfig.new()
	d_cfg.seed = 998877
	d_cfg.use_fixed_seed = true

	var pipeline: DungeonPipeline = DungeonPipeline.new()
	var d_res = pipeline.generate(d_cfg)
	assert(d_res != null, "DungeonResult generated successfully")

	var sem_orch: SemanticOrchestrator = SemanticOrchestrator.new()
	var sem_res = sem_orch.generate_semantics(d_res, d_cfg)
	assert(sem_res != null and sem_res.gameplay_valid, "SemanticResult valid")

	var l_cfg: DungeonLightingConfig = DungeonLightingConfig.new()
	var gen: DungeonLightingGenerator = DungeonLightingGenerator.new()

	var run1 = gen.generate_lighting(sem_res, l_cfg, 998877)
	var run2 = gen.generate_lighting(sem_res, l_cfg, 998877)

	assert(run1.has_lights(), "Run 1 has lights")
	assert(run1.placements.size() == run2.placements.size(), "Exact placement count matches on same seed")

	for i in range(run1.placements.size()):
		assert(run1.placements[i].cell == run2.placements[i].cell, "Exact cell matches on same seed at index %d" % i)
		assert(run1.placements[i].wall_side == run2.placements[i].wall_side, "Exact wall side matches at index %d" % i)

	print("  [OK] Exact 100%% determinism on identical seed verified (%d lights placed)." % run1.placements.size())

	var run_diff = gen.generate_lighting(sem_res, l_cfg, 112233)
	print("  [OK] Differential seed test generated %d lights." % run_diff.placements.size())

	print("==================================================================")
	print("[PASS] test_lighting_determinism completado con éxito!")
	print("==================================================================")
	quit(0)
