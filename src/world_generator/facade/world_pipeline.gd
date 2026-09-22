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


static func generate_regional_hydrology(seed_val: int, profile: WorldProfile = null, region_origin: Vector2i = Vector2i.ZERO) -> HydrologyResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)
	context.region_origin = region_origin
	TerrainStage.new().execute(context)
	var hydro: HydrologyResult = _HydrologyStageScript.solve_global(context)

	if region_origin != Vector2i.ZERO:
		_translate_hydrology_to_world(hydro, region_origin, profile.cell_size)

	return hydro


static func _translate_hydrology_to_world(hydro: HydrologyResult, origin: Vector2i, cell_size: float) -> void:
	if hydro == null or origin == Vector2i.ZERO:
		return

	var offset_3d := Vector3(float(origin.x) * cell_size, 0.0, float(origin.y) * cell_size)

	var new_water_cells: Dictionary = {}
	for pos in hydro.water_cells:
		new_water_cells[pos + origin] = hydro.water_cells[pos]
	hydro.water_cells = new_water_cells

	for lake in hydro.lakes:
		var old_cells: Array = lake.get("cells", [])
		var new_cells: Array[Vector2i] = []
		for cp in old_cells:
			new_cells.append(cp + origin)
		lake["cells"] = new_cells
		if "spillway_pos" in lake:
			lake["spillway_pos"] = lake["spillway_pos"] + origin
		if "min_pos" in lake:
			lake["min_pos"] = lake["min_pos"] + origin
		if "max_pos" in lake:
			lake["max_pos"] = lake["max_pos"] + origin

	for river in hydro.rivers:
		var old_cells: Array = river.get("cells", [])
		var new_cells: Array[Vector2i] = []
		for cp in old_cells:
			new_cells.append(cp + origin)
		river["cells"] = new_cells

		var old_pts: Array = river.get("points", [])
		var new_pts: Array[Vector3] = []
		for pt in old_pts:
			new_pts.append(pt + offset_3d)
		river["points"] = new_pts

	var new_acc: Dictionary = {}
	for pos in hydro.accumulation:
		new_acc[pos + origin] = hydro.accumulation[pos]
	hydro.accumulation = new_acc

	var new_zones: Dictionary = {}
	for pos in hydro.zones:
		new_zones[pos + origin] = hydro.zones[pos]
	hydro.zones = new_zones

	var new_inf: Dictionary = {}
	for pos in hydro.hydraulic_influence:
		new_inf[pos + origin] = hydro.hydraulic_influence[pos]
	hydro.hydraulic_influence = new_inf

	var new_ex: Dictionary = {}
	for pos in hydro.exclusion_mask:
		new_ex[pos + origin] = hydro.exclusion_mask[pos]
	hydro.exclusion_mask = new_ex

	hydro.build_spatial_index(cell_size)


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
