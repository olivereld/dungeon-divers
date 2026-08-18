class_name MultiFloorGenerator
extends RefCounted

## Orquestador maestro de generación de mazmorras multinivel (Fase 10).
## Genera cada piso de forma pura e independiente, vinculándolos mediante StairPlanner
## y derivando deterministamente todas las sub-semillas con SeedDerivation (v1).

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _StairPlannerScript = preload("res://src/dungeon_generator/core/stair_planner.gd")
const _SeedDerivationScript = preload("res://src/dungeon_generator/core/seed_derivation.gd")
const _DungeonFloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")
const _DungeonMultiFloorResultScript = preload("res://src/dungeon_generator/core/data/dungeon_multi_floor_result.gd")

var _pipeline: DungeonPipeline
var _stair_planner: StairPlanner

func _init(pipeline: DungeonPipeline = null, stair_planner: StairPlanner = null) -> void:
	_pipeline = pipeline if pipeline != null else _DungeonPipelineScript.new()
	_stair_planner = stair_planner if stair_planner != null else _StairPlannerScript.new()

## Genera una mazmorra completa multinivel de forma determinista y reproducible.
func generate_multi_floor(config: DungeonConfig, master_seed: int = 0) -> DungeonMultiFloorResult:
	var start_time: int = Time.get_ticks_msec()

	if config == null:
		config = DungeonConfig.new()

	var num_floors: int = maxi(1, config.total_floors)
	var eff_master_seed: int = master_seed if master_seed != 0 else config.get_effective_seed()
	if eff_master_seed == 0:
		eff_master_seed = 1337

	var multi_result: DungeonMultiFloorResult = _DungeonMultiFloorResultScript.new(eff_master_seed)

	# 1. Generar traza determinista de semillas
	var floor_numbers: Array[int] = []
	for f in range(num_floors):
		floor_numbers.append(f)
	multi_result.seed_trace = _SeedDerivationScript.build_multi_floor_seed_trace(eff_master_seed, floor_numbers)

	# 2. Generar cada piso individualmente mediante DungeonPipeline
	for f in range(num_floors):
		var floor_cfg: DungeonConfig = config.duplicate() as DungeonConfig
		floor_cfg.floor_number = f
		floor_cfg.seed = _SeedDerivationScript.derive_floor_seed(eff_master_seed, f)
		floor_cfg.use_fixed_seed = true

		var d_res: DungeonResult = _pipeline.generate(floor_cfg)
		if d_res == null:
			push_error("[MultiFloorGenerator] Falló la generación del piso %d con semilla %d" % [f, floor_cfg.seed])
			multi_result.is_valid = false
			return multi_result

		var floor_data: DungeonFloorData = _DungeonFloorDataScript.from_dungeon_result(d_res)
		multi_result.add_floor(floor_data)

	# 3. Planificar y conectar escaleras entre pisos consecutivos (F0 <-> F1 <-> F2 ...)
	for f in range(num_floors - 1):
		var floor_a: DungeonFloorData = multi_result.get_floor(f)
		var floor_b: DungeonFloorData = multi_result.get_floor(f + 1)
		var stairs_seed: int = _SeedDerivationScript.derive_stairs_seed(eff_master_seed, f)

		var vconn: FloorConnection = _stair_planner.plan_stairs_between_floors(floor_a, floor_b, stairs_seed)
		if vconn != null:
			multi_result.add_vertical_connection(vconn)
		else:
			push_warning("[MultiFloorGenerator] No se pudo establecer conexión de escaleras entre piso %d y %d" % [f, f + 1])

	multi_result.is_valid = (multi_result.get_floor_count() == num_floors)
	multi_result.total_generation_time_ms = float(Time.get_ticks_msec() - start_time)

	return multi_result
