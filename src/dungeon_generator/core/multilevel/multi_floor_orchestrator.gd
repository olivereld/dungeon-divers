class_name MultiFloorOrchestrator
extends RefCounted

## Orquestador desacoplado de generación y composición multinivel (Fase 10 / M8).
## Orquesta: VerticalProgressionSolver -> DungeonPipeline -> SemanticOrchestrator -> FloorConnectionPlanner -> MultiFloorValidator.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _VerticalProgressionSolverScript = preload("res://src/dungeon_generator/core/multilevel/vertical_progression_solver.gd")
const _FloorConnectionPlannerScript = preload("res://src/dungeon_generator/core/multilevel/floor_connection_planner.gd")
const _MultiFloorValidatorScript = preload("res://src/dungeon_generator/core/multilevel/multi_floor_validator.gd")
const _SeedDerivationScript = preload("res://src/dungeon_generator/core/seed_derivation.gd")
const _DungeonFloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")
const _DungeonMultiFloorResultScript = preload("res://src/dungeon_generator/core/data/dungeon_multi_floor_result.gd")

var _pipeline: DungeonPipeline
var _semantic_orchestrator := _SemanticOrchestratorScript.new()
var _progression_solver := _VerticalProgressionSolverScript.new()
var _connection_planner := _FloorConnectionPlannerScript.new()
var _validator := _MultiFloorValidatorScript.new()

func _init(pipeline: DungeonPipeline = null) -> void:
	_pipeline = pipeline if pipeline != null else _DungeonPipelineScript.new()

## Genera una mazmorra completa multinivel de forma determinista y estructurada.
func generate_multi_floor(
	config: DungeonConfig,
	master_seed: int = 0,
	diagnostics_enabled: bool = true
) -> DungeonMultiFloorResult:
	var start_time: int = Time.get_ticks_msec()

	if config == null:
		config = DungeonConfig.new()

	var num_floors: int = maxi(1, config.total_floors)
	var eff_master_seed: int = master_seed if master_seed != 0 else config.get_effective_seed()
	if eff_master_seed == 0:
		eff_master_seed = 1337

	var multi_result: DungeonMultiFloorResult = _DungeonMultiFloorResultScript.new(eff_master_seed)

	# 1. Resolver roles de progresión vertical para cada piso
	var roles = _progression_solver.solve_progression_roles(config)

	# 2. Generar traza determinista de semillas
	var floor_numbers: Array[int] = []
	for f in range(num_floors):
		floor_numbers.append(f)
	multi_result.seed_trace = _SeedDerivationScript.build_multi_floor_seed_trace(eff_master_seed, floor_numbers)

	# 3. Generar cada piso mediante Pipeline + SemanticOrchestrator
	for f in range(num_floors):
		var role = roles[f]
		var floor_seed: int = _SeedDerivationScript.derive_floor_seed(eff_master_seed, f)
		var floor_cfg: DungeonConfig = _progression_solver.create_floor_config(config, role, floor_seed)

		var d_res: DungeonResult = _pipeline.generate(floor_cfg, DungeonPipeline.MAX_ATTEMPTS, false, diagnostics_enabled)
		if d_res == null:
			if diagnostics_enabled:
				push_error("[MultiFloorOrchestrator] Falló la generación del piso %d con semilla %d" % [f, floor_seed])
			multi_result.is_valid = false
			multi_result.failure_type = _pipeline.last_failure_type
			multi_result.failure_reason = _pipeline.last_failure_reason
			multi_result.failure_stage = _pipeline.last_failure_stage
			multi_result.failure_seed = floor_seed
			return multi_result

		# Generar semántica del piso
		var sem_res: DungeonSemanticResult = _semantic_orchestrator.generate_semantics(d_res, floor_cfg)
		if sem_res == null or not sem_res.gameplay_valid:
			if diagnostics_enabled:
				push_warning("[MultiFloorOrchestrator] Falló validación semántica en piso %d" % f)
			multi_result.is_valid = false
			multi_result.failure_type = "SEMANTIC"
			multi_result.failure_reason = "FLOOR_SEMANTICS_INVALID"
			multi_result.failure_stage = "semantic"
			multi_result.failure_seed = floor_seed
			return multi_result

		var floor_data: DungeonFloorData = _DungeonFloorDataScript.from_dungeon_result(d_res)
		multi_result.add_floor(floor_data)

	# 4. Planificar y conectar escaleras entre pisos consecutivos
	for f in range(num_floors - 1):
		var floor_a: DungeonFloorData = multi_result.get_floor(f)
		var floor_b: DungeonFloorData = multi_result.get_floor(f + 1)
		var stairs_seed: int = _SeedDerivationScript.derive_stairs_seed(eff_master_seed, f)

		var vconn: FloorConnection = _connection_planner.plan_stairs_between_floors(floor_a, floor_b, stairs_seed)
		if vconn != null:
			multi_result.add_vertical_connection(vconn)
		else:
			if diagnostics_enabled:
				push_warning("[MultiFloorOrchestrator] No se pudo establecer conexión de escaleras entre piso %d y %d" % [f, f + 1])
			multi_result.is_valid = false
			multi_result.failure_type = "STRUCTURAL"
			multi_result.failure_reason = "STAIR_CONNECTION_FAILED"
			multi_result.failure_stage = "stairs"
			multi_result.failure_seed = stairs_seed
			return multi_result

	# 5. Validación formal de la mazmorra multinivel completa
	var val_res = _validator.validate(multi_result)
	multi_result.is_valid = val_res.is_valid
	if not val_res.is_valid:
		multi_result.failure_type = "VALIDATION"
		multi_result.failure_reason = val_res.errors[0] if not val_res.errors.is_empty() else "UNKNOWN_VALIDATION_ERROR"

	multi_result.total_generation_time_ms = float(Time.get_ticks_msec() - start_time)
	return multi_result
