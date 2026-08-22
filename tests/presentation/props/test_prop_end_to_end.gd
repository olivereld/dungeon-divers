extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_prop_end_to_end ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 112233
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var pres_builder := DungeonPresentationBuilderScript.new()
	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var biome := BiomeProfileScript.new()
	var pres_res = pres_builder.build_presentation(sem, parent_node, biome, cfg)

	assert(pres_res != null, "FAIL: Presentation result cannot be null")
	assert(not pres_res.has_blocking_errors(), "FAIL: Blocking errors detected in presentation")
	assert(pres_res.total_tiles_rendered > 0, "FAIL: Tiles rendered must be > 0")

	# Contar Props instanciados en presentation_root
	var prop_count: int = 0
	for child in pres_res.presentation_root.get_children():
		if child.name.begins_with("Prop_"):
			prop_count += 1

	print("  [OK] Presentation staging created successfully.")
	print("  [OK] Total spawned props: %d" % prop_count)
	assert(prop_count > 0, "FAIL: Expected at least one prop spawned in dungeon rooms")

	parent_node.queue_free()
	print("[PASS] test_prop_end_to_end completed successfully!")
	quit(0)
