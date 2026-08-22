extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const PresentationStructuralRendererScript = preload("res://src/presentation/geometry/presentation_structural_renderer.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_structural_renderer ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 12345
	cfg.use_fixed_seed = true

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	var structural_renderer := PresentationStructuralRendererScript.new()
	var staging_root := Node3D.new()
	root.add_child(staging_root)

	var biome := BiomeProfileScript.new()
	var render_result = structural_renderer.render_structure(
		partition, sem, cfg, biome, staging_root, null, null
	)

	assert(render_result.get("floor_rendered", false) == true, "FAIL: Floor must be rendered")
	assert(render_result.get("walls_rendered", false) == true, "FAIL: Walls must be rendered")

	var has_floor_nodes: bool = false
	var has_wall_nodes: bool = false
	for child in staging_root.get_children():
		if child.name == "FloorMeshInstance" or child.name.begins_with("Floor"):
			has_floor_nodes = true
		if child.name == "ContinuousWalls":
			has_wall_nodes = true

	assert(has_floor_nodes, "FAIL: Floor node not found in staging root")
	assert(has_wall_nodes, "FAIL: Wall node not found in staging root")

	staging_root.queue_free()

	print("  [OK] PresentationStructuralRenderer successfully built floors and continuous walls into staging.")
	print("[PASS] test_presentation_structural_renderer completed successfully.")
	quit(0)
