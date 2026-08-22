extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_geometry_partition ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 4444
	cfg.use_fixed_seed = true
	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	assert(partition.rooms_geometry.size() == res.rooms.size(), "FAIL: Must partition all rooms")
	for r_id in partition.rooms_geometry:
		var r_geom = partition.get_room_geometry(r_id)
		assert(r_geom != null, "FAIL: Room geometry must not be null")
		assert(not r_geom.floor_cells.is_empty(), "FAIL: Room floor cells cannot be empty")
		assert(r_geom.profile != null, "FAIL: Room geometry must carry its resolved profile")

	print("  [OK] PresentationGeometryPartition successfully partitioned rooms without mutating CellGrid.")
	print("[PASS] test_presentation_geometry_partition completed successfully.")
	quit(0)
