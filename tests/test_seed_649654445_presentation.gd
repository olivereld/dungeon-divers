extends SceneTree

## Test unitario para verificar la materialización 3D limpia en la semilla 649654445.

func _init() -> void:
	print("--- Running test_seed_649654445_presentation ---")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.seed = 649654445
	config.use_fixed_seed = true
	config.grid_width = 48
	config.grid_height = 48

	var res: DungeonResult = pipeline.generate(config, 5, false)
	assert(res != null and res.grid != null, "Generation must succeed")

	var orchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd").new()
	var semantic = orchestrator.generate_semantics(res, config)
	assert(semantic != null and semantic.gameplay_valid, "Semantic validation must succeed")

	var builder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd").new()
	var biome = BiomeProfile.new()

	var root := Node3D.new()
	var pres_res = builder.build_presentation(semantic, root, biome, config, null, true)
	assert(pres_res.success, "Presentation build must succeed")

	var walls_node = pres_res.presentation_root.get_node_or_null("ContinuousWalls")
	assert(walls_node != null, "ContinuousWalls node must exist")
	assert(walls_node.mesh.get_surface_count() > 0, "Wall mesh must have surfaces")

	print("  [OK] 3D Presentation built cleanly with %d surfaces" % walls_node.mesh.get_surface_count())
	print("[PASS] test_seed_649654445_presentation completed successfully!")
	quit(0)
