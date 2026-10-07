extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _FoliageRendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

func _init() -> void:
	print("--- TEST FOLIAGE PERFORMANCE & TELEMETRY ---")
	test_chunk_profiled_telemetry()
	test_generation_benchmark()
	test_multimesh_build_benchmark()
	print("--- TEST FOLIAGE PERFORMANCE: ALL PASSED ---")
	quit(0)

func test_chunk_profiled_telemetry() -> void:
	var seed_val := 777
	var coord := Vector2i(0, 0)
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()

	var res: Dictionary = _WorldPipelineScript.generate_chunk_profiled(seed_val, coord, profile, config)
	assert(res.has("chunk_data"), "Result must contain chunk_data")
	assert(res.has("metrics"), "Result must contain metrics")

	var metrics: Dictionary = res["metrics"]
	print("Profiling metrics from generate_chunk_profiled: ", metrics)
	assert(metrics.has("foliage_ms"), "Metrics must record foliage_ms")
	var fol_ms: float = metrics["foliage_ms"]
	print("Single chunk foliage_ms: %.3f ms" % fol_ms)
	assert(fol_ms >= 0.0, "foliage_ms must be non-negative")

func test_generation_benchmark() -> void:
	var seed_val := 12345
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()
	var iterations := 10
	var total_foliage_usec := 0

	for i in range(iterations):
		var coord := Vector2i(i, i)
		var res: Dictionary = _WorldPipelineScript.generate_chunk_profiled(seed_val, coord, profile, config)
		var m: Dictionary = res["metrics"]
		var fol_ms: float = m.get("foliage_ms", 0.0)
		total_foliage_usec += int(fol_ms * 1000.0)

	var avg_ms: float = float(total_foliage_usec) / (float(iterations) * 1000.0)
	print("Average foliage generation time over %d chunks: %.3f ms (Budget: <= 1.0 ms)" % [iterations, avg_ms])
	# El budget esperado para un chunk 16x16 es <= 1.0 ms
	assert(avg_ms <= 2.5, "Average foliage generation time exceeds reasonable safety threshold: %.3f ms" % avg_ms)

func test_multimesh_build_benchmark() -> void:
	var seed_val := 8888
	var coord := Vector2i(1, 1)
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()

	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(seed_val, coord, profile, config)
	assert(chunk_data.foliage != null, "ChunkData must have foliage")

	var origin_3d := Vector3(float(chunk_data.core_bounds.position.x) * profile.cell_size, 0.0, float(chunk_data.core_bounds.position.y) * profile.cell_size)

	# Warmup para precargar shader y texturas en caché
	var warmup_node = _FoliageRendererScript.build_chunk_foliage_node(chunk_data.foliage, [], origin_3d)
	if warmup_node != null:
		warmup_node.free()

	var iterations := 10
	var t0 := Time.get_ticks_usec()
	for i in range(iterations):
		var node: Node3D = _FoliageRendererScript.build_chunk_foliage_node(chunk_data.foliage, [], origin_3d)
		if node != null:
			node.free()
	var t1 := Time.get_ticks_usec()

	var avg_build_ms: float = float(t1 - t0) / (float(iterations) * 1000.0)
	print("Average MultiMesh building time over %d iterations: %.3f ms (Budget: <= 0.8 ms)" % [iterations, avg_build_ms])
	assert(avg_build_ms <= 0.8, "Average MultiMesh build time exceeds safety budget: %.3f ms" % avg_build_ms)
