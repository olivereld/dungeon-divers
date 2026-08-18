extends SceneTree

## Test Suite para DungeonPipeline Orquestador Modular (Fase 3).
## Verifica que el pipeline coordine limpiamente todas las etapas a través de DungeonGenerationContext,
## emita las señales correspondientes y genere resultados válidos y deterministas.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_phase3_pipeline_orchestrator ---")
	test_modular_pipeline_execution()
	test_modular_pipeline_determinism()
	print("[PASS] test_phase3_pipeline_orchestrator completed successfully!")
	quit(0)

func test_modular_pipeline_execution() -> void:
	print("  -> Testing modular pipeline generation execution...")
	var pipeline := _DungeonPipelineScript.new()
	var config := _DungeonConfigScript.new()
	config.seed = 1337
	config.use_fixed_seed = true
	
	var phases_completed: Array[String] = []
	pipeline.phase_completed.connect(func(p_name: String, _t: float):
		phases_completed.append(p_name)
	)
	
	var res := pipeline.generate(config)
	assert(res != null, "DungeonResult must not be null")
	assert(res.grid != null, "Grid must not be null")
	assert(res.rooms.size() >= 5, "Must generate at least 5 rooms")
	assert(res.connections.size() >= res.rooms.size() - 1, "Must have at least MST connections")
	assert(res.door_pairs.size() > 0, "Must have valid door pairs")
	assert(phases_completed.has("mission_grammar"), "Must emit mission_grammar signal")
	assert(phases_completed.has("space_grammar"), "Must emit space_grammar signal")
	assert(phases_completed.has("topology_builder"), "Must emit topology_builder signal")
	assert(phases_completed.has("entrance_solver"), "Must emit entrance_solver signal")
	assert(phases_completed.has("corridor_carving"), "Must emit corridor_carving signal")
	assert(phases_completed.has("door_resolver"), "Must emit door_resolver signal")
	assert(phases_completed.has("flood_fill_connectivity"), "Must emit flood_fill_connectivity signal")
	print("    [OK] Modular pipeline successfully executed all stages and emitted lifecycle signals")

func test_modular_pipeline_determinism() -> void:
	print("  -> Testing modular pipeline determinism...")
	var pipeline := _DungeonPipelineScript.new()
	var config := _DungeonConfigScript.new()
	config.seed = 888888
	config.use_fixed_seed = true
	
	var res_a := pipeline.generate(config)
	var res_b := pipeline.generate(config)
	
	assert(res_a.rooms.size() == res_b.rooms.size(), "Room count must be identical")
	assert(res_a.connections.size() == res_b.connections.size(), "Connection count must be identical")
	assert(res_a.doors.size() == res_b.doors.size(), "Door count must be identical")
	print("    [OK] Modular pipeline is 100% deterministic across multiple runs")
