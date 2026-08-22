extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_archetype_geometry_isolation ---")
	print("==================================================================")

	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()
	var ctx_builder := PresentationContextBuilderScript.new()

	var test_seed: int = 54321

	# Config MAUSOLEUM
	var cfg_m := DungeonConfigScript.new()
	cfg_m.seed = test_seed
	cfg_m.use_fixed_seed = true
	cfg_m.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM
	var res_m = pipeline.generate(cfg_m, 5, true)
	var sem_m = orchestrator.generate_semantics(res_m, cfg_m)
	var ctx_m = ctx_builder.build_contexts(sem_m)

	# Config FORTRESS
	var cfg_f := DungeonConfigScript.new()
	cfg_f.seed = test_seed
	cfg_f.use_fixed_seed = true
	cfg_f.dungeon_archetype = DungeonArchetypeScript.Type.FORTRESS
	var res_f = pipeline.generate(cfg_f, 5, true)
	var sem_f = orchestrator.generate_semantics(res_f, cfg_f)
	var ctx_f = ctx_builder.build_contexts(sem_f)

	# 1. Verificar que la topología lógica generada con la misma semilla es IDÉNTICA
	assert(res_m.rooms.size() == res_f.rooms.size(), "FAIL: Topologies must match for same seed")
	for i in range(res_m.rooms.size()):
		assert(res_m.rooms[i].rect == res_f.rooms[i].rect, "FAIL: Room rects must be identical")

	# 2. Verificar que los estilos arquitectónicos asignados son DIFERENTES y específicos del arquetipo
	var dominant_m = ctx_builder.get_dominant_profile(ctx_m, cfg_m.dungeon_archetype)
	var dominant_f = ctx_builder.get_dominant_profile(ctx_f, cfg_f.dungeon_archetype)

	assert(dominant_m.wall_style == ArchitecturalStyleScript.WallStyle.DARK_STONE)
	assert(dominant_f.wall_style == ArchitecturalStyleScript.WallStyle.FORTRESS_STONE)

	print("  [OK] Identical logical geometry validated across different archetypes.")
	print("  [OK] Presentation styles accurately isolated from core topological layout.")
	print("[PASS] test_archetype_geometry_isolation completed successfully.")
	quit(0)
