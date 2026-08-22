extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_per_room_architectural_presentation ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 7777
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem_res = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem_res)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem_res)

	# Verificar que las salas tienen contextos y perfiles propios diferenciados según propósito
	assert(partition.rooms_geometry.size() == res.rooms.size())
	for r_id in partition.rooms_geometry:
		var r_geom = partition.get_room_geometry(r_id)
		assert(r_geom.profile != null, "FAIL: Each room geometry must have a presentation profile")

	var pres_builder := DungeonPresentationBuilderScript.new()
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	var biome := BiomeProfileScript.new()

	var pres_res = pres_builder.build_presentation(sem_res, parent_node, biome, cfg)
	assert(pres_res != null)
	assert(not pres_res.has_blocking_errors())

	parent_node.queue_free()
	print("  [OK] Per-room architectural presentation verified.")
	print("[PASS] test_per_room_architectural_presentation completed successfully.")
	quit(0)
