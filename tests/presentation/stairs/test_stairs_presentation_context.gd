extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const StairsPresentationContextScript = preload("res://src/presentation/architecture/stairs_presentation_context.gd")
const StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_stairs_presentation_context ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 445566
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.TEMPLE

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	# Simular un StairData dentro de la sala inicial
	var start_room_id = sem.start_room_id
	var start_geom = partition.get_room_geometry(start_room_id)
	assert(start_geom != null and not start_geom.floor_cells.is_empty())

	var stair_cell: Vector2i = start_geom.floor_cells[0]
	var stair_data = StairDataScript.new("stair_1", 0, stair_cell, 0.0, "conn_1", false, 1)

	var stair_ctx = StairsPresentationContextScript.create_from_stair(stair_data, partition)
	assert(stair_ctx != null, "FAIL: StairsPresentationContext cannot be null")
	assert(stair_ctx.room_id == start_room_id, "FAIL: Room ID mismatch")
	assert(stair_ctx.profile != null, "FAIL: Profile cannot be null")
	assert(stair_ctx.resolved_style in [
		ArchitecturalStyleScript.StairsStyle.STONE,
		ArchitecturalStyleScript.StairsStyle.WOOD
	], "FAIL: resolved_style must be a valid StairsStyle")

	print("  [OK] StairsPresentationContext successfully resolved from room profile.")
	print("[PASS] test_stairs_presentation_context completed successfully.")
	quit(0)
