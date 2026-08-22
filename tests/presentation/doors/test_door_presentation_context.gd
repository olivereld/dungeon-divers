extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const DoorPresentationContextScript = preload("res://src/presentation/architecture/door_presentation_context.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_door_presentation_context ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 334455
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	var door_manifests = DoorManifestFactoryScript.create_door_manifests(sem.door_pairs)
	assert(not door_manifests.is_empty(), "FAIL: Door manifests cannot be empty")

	for manifest in door_manifests:
		var door_ctx = DoorPresentationContextScript.create_from_manifest(manifest, partition)
		assert(door_ctx != null, "FAIL: DoorPresentationContext cannot be null")
		assert(door_ctx.door_id == manifest.door_id, "FAIL: door_id mismatch")
		assert(door_ctx.resolved_style in [
			ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
			ArchitecturalStyleScript.DoorStyle.WOOD_LEAF,
			ArchitecturalStyleScript.DoorStyle.HEAVY_IRON,
			ArchitecturalStyleScript.DoorStyle.MINE_FRAME
		], "FAIL: resolved_style must be a valid DoorStyle")

	print("  [OK] DoorPresentationContext successfully built for all door manifests.")
	print("  [OK] Contextual door style resolution verified.")
	print("[PASS] test_door_presentation_context completed successfully.")
	quit(0)
