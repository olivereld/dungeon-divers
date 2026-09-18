class_name WorldPipeline
extends RefCounted

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")

static func generate(seed_val: int, profile: WorldProfile = null) -> WorldResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)
	_execute_stages(context)

	return context.result


static func generate_chunk(
	seed_val: int,
	chunk_coord: Vector2i,
	profile: WorldProfile = null,
	config: ChunkConfig = null,
	shared_hydrology: HydrologyResult = null
) -> ChunkData:
	if profile == null:
		profile = TaigaWorldProfile.new()

	if config == null:
		config = ChunkConfig.new()

	var context := ChunkGenerationContext.new(
		seed_val,
		profile,
		chunk_coord,
		config,
		shared_hydrology
	)

	_execute_stages(context)

	context.result.trim_to_core()

	return context.result


static func generate_chunk_profiled(
	seed_val: int,
	chunk_coord: Vector2i,
	profile: WorldProfile = null,
	config: ChunkConfig = null,
	shared_hydrology: HydrologyResult = null
) -> Dictionary:
	if profile == null:
		profile = TaigaWorldProfile.new()

	if config == null:
		config = ChunkConfig.new()

	var context := ChunkGenerationContext.new(
		seed_val,
		profile,
		chunk_coord,
		config,
		shared_hydrology
	)

	var metrics: Dictionary = {}
	var t_start := Time.get_ticks_usec()
	_execute_stages(context, metrics)
	var t_end := Time.get_ticks_usec()

	context.result.trim_to_core()
	metrics["generation_total_ms"] = float(t_end - t_start) / 1000.0

	return {
		"chunk_data": context.result,
		"metrics": metrics
	}


static func generate_regional_hydrology(seed_val: int, profile: WorldProfile = null) -> HydrologyResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)
	TerrainStage.new().execute(context)
	var hydro: HydrologyResult = _HydrologyStageScript.solve_global(context)
	return hydro


static func _execute_stages(context: WorldGenerationContext, profiler: Variant = null) -> void:
	var stage_specs: Array[Dictionary] = [
		{"name": "terrain_ms", "stage": TerrainStage.new()},
		{"name": "hydrology_ms", "stage": _HydrologyStageScript.new()},
		{"name": "ecology_ms", "stage": EcologyStage.new()},
		{"name": "navigation_ms", "stage": NavigationStage.new()},
		{"name": "vegetation_ms", "stage": VegetationStage.new()},
	]

	var is_profiling: bool = (profiler is Dictionary)
	if is_profiling:
		context.telemetry = profiler

	for spec in stage_specs:
		var stage: WorldStage = spec["stage"]
		if is_profiling:
			var t0 := Time.get_ticks_usec()
			stage.execute(context)
			var t1 := Time.get_ticks_usec()
			profiler[spec["name"]] = float(t1 - t0) / 1000.0
		else:
			stage.execute(context)
