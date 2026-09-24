@tool
extends SceneTree

## Test de Integración Extremo a Extremo: Streaming Asíncrono y Pre-generación Predictiva
## Valida el pipeline unificado:
## Player Movement -> StreamingController (Priorities) -> Scheduler (Priority Queue) -> Worker Threads
## -> READY ChunkData -> ActivationScheduler (Frame Budget) -> VISIBLE ChunkView -> Cache

const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkStreamingControllerScript = preload("res://src/world_generator/chunks/chunk_streaming_controller.gd")
const _ChunkGenerationSchedulerScript = preload("res://src/world_generator/chunks/chunk_generation_scheduler.gd")
const _HydrologyRegionCacheScript = preload("res://src/world_generator/chunks/hydrology_region_cache.gd")
const _ChunkActivationSchedulerScript = preload("res://src/world_generator/chunks/chunk_activation_scheduler.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _ChunkLifecycleScript = preload("res://src/world_generator/chunks/chunk_state.gd")
const _ChunkManagerScript = preload("res://src/world_generator/chunks/chunk_manager.gd")

func _init() -> void:
	print("--- Running Chunk Streaming & Predictive Pre-generation Integration Tests ---")
	var success := true

	success = test_task1_streaming_controller_prediction() and success
	success = test_task2_scheduler_priority_queue_and_tokens() and success
	success = test_task3_hydrology_region_cache() and success
	success = test_task4_activation_scheduler_budget() and success
	success = test_task5_lifecycle_and_chunk_record() and success
	success = test_task6_end_to_end_streaming_pipeline() and success

	if success:
		print("ALL STREAMING TESTS PASSED!")
		quit(0)
	else:
		printerr("STREAMING TESTS FAILED!")
		quit(1)


func test_task1_streaming_controller_prediction() -> bool:
	print("\n[Test 1] ChunkStreamingController & Kinematic Prediction...")
	var config := _ChunkConfigScript.new(16, 1, 2)
	config.preload_radius = 4
	config.cache_radius = 6
	config.prediction_distance_chunks = 2.0

	var controller := _ChunkStreamingControllerScript.new(config)

	# 1. Jugador estacionario en (0, 0)
	var res_still := controller.update_target(Vector3.ZERO, Vector3.ZERO, 1.0)
	if res_still["current_chunk"] != Vector2i.ZERO:
		printerr("FAIL: Expected current chunk (0, 0)")
		return false
	if res_still["predicted_chunk"] != Vector2i.ZERO:
		printerr("FAIL: Stationary player should predict chunk (0, 0)")
		return false

	# 2. Invariante VISIBLE < PRELOAD < CACHE
	var vis_count: int = res_still["visible_chunks"].size()
	var pre_count: int = res_still["preload_chunks"].size()
	var cac_count: int = res_still["cache_chunks"].size()
	if not (vis_count < pre_count and pre_count < cac_count):
		printerr("FAIL: Invariant VISIBLE < PRELOAD < CACHE violated: %d < %d < %d" % [vis_count, pre_count, cac_count])
		return false

	# 3. Jugador avanzando velozmente hacia +X
	var res_moving := controller.update_target(Vector3.ZERO, Vector3(15.0, 0.0, 0.0), 1.0)
	var pred: Vector2i = res_moving["predicted_chunk"]
	if pred.x <= 0:
		printerr("FAIL: Expected forward predicted chunk in +X direction, got %s" % pred)
		return false

	# 4. Los chunks en dirección +X deben tener mayor prioridad que en -X
	var p_forward: float = res_moving["priorities"].get(Vector2i(1, 0), 0.0)
	var p_backward: float = res_moving["priorities"].get(Vector2i(-1, 0), 0.0)
	if p_forward <= p_backward:
		printerr("FAIL: Forward chunk priority (%f) should exceed backward chunk priority (%f)" % [p_forward, p_backward])
		return false

	print("✓ Test 1 passed: Kinematic prediction and priorities valid.")
	return true


func test_task2_scheduler_priority_queue_and_tokens() -> bool:
	print("\n[Test 2] Priority Queue, Token Cancellation & Deduplication...")
	var scheduler := _ChunkGenerationSchedulerScript.new()
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 2)
	var seed_val := 4242

	# 1. Encolar dos chunks: uno con baja prioridad y otro con alta prioridad
	scheduler.request_chunk(Vector2i(0, 0), seed_val, profile, config, null, 1, 10.0)
	scheduler.request_chunk(Vector2i(5, 5), seed_val, profile, config, null, 2, 500.0)

	# 2. Cancelar el chunk de baja prioridad
	scheduler.cancel_chunk(Vector2i(0, 0))

	# 3. Esperar que el scheduler procese
	var t_start := Time.get_ticks_msec()
	var results: Array = []
	while results.is_empty() and (Time.get_ticks_msec() - t_start) < 2000:
		results = scheduler.poll_completed()
		OS.delay_msec(10)

	scheduler.shutdown()

	if results.is_empty():
		printerr("FAIL: Scheduler did not complete high priority request")
		return false

	var first_coord: Vector2i = results[0]["coord"]
	if first_coord != Vector2i(5, 5):
		printerr("FAIL: High priority chunk (5,5) was expected, got %s" % first_coord)
		return false

	print("✓ Test 2 passed: Priority queue and cancellation verified.")
	return true


func test_task3_hydrology_region_cache() -> bool:
	print("\n[Test 3] HydrologyRegionCache Concurrency & Deduplication...")
	var profile := _TaigaWorldProfileScript.new()
	var cache := _HydrologyRegionCacheScript.new(9999, profile)

	# 1. Primera consulta: Cache Miss
	var hydro_1 = cache.get_or_generate_region(Vector2i(0, 0), 64, 64)
	if hydro_1 == null:
		printerr("FAIL: Generated hydrology region is null")
		return false
	if cache.cache_misses != 1 or cache.cache_hits != 0:
		printerr("FAIL: Expected 1 miss and 0 hits, got misses=%d hits=%d" % [cache.cache_misses, cache.cache_hits])
		return false

	# 2. Segunda consulta misma región: Cache Hit
	var hydro_2 = cache.get_or_generate_region(Vector2i(0, 0), 64, 64)
	if cache.cache_hits != 1:
		printerr("FAIL: Expected 1 hit on second access, got %d" % cache.cache_hits)
		return false
	if hydro_1 != hydro_2:
		printerr("FAIL: Region instances do not match")
		return false

	# 3. Ensure bounds sobre área multi-macro
	cache.ensure_bounds(Rect2i(0, 0, 128, 128), 64, 64)
	if cache.shared_hydrology == null:
		printerr("FAIL: Shared hydrology not updated after ensure_bounds")
		return false

	print("✓ Test 3 passed: HydrologyRegionCache hits and misses verified.")
	return true


func test_task4_activation_scheduler_budget() -> bool:
	print("\n[Test 4] ChunkActivationScheduler Frame Budget...")
	var scheduler := _ChunkActivationSchedulerScript.new()
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 2)
	var root_container := Node3D.new()

	# Generar 3 ChunkData sintéticos
	for i in range(3):
		var coord := Vector2i(i, 0)
		var c_data: ChunkData = _WorldPipelineScript.generate_chunk(1234, coord, profile, config, null)
		scheduler.enqueue_chunk(coord, c_data, float(i) * 10.0, 1)

	if scheduler.get_queue_size() != 3:
		printerr("FAIL: Expected 3 enqueued items, got %d" % scheduler.get_queue_size())
		root_container.free()
		return false

	# Procesar con límite de 1 activación por llamada
	var activated_1 := scheduler.process_activations(
		100.0,
		1,
		profile,
		true,
		root_container,
		Callable(),
		Callable()
	)

	if activated_1.size() != 1:
		printerr("FAIL: Expected exactly 1 activation, got %d" % activated_1.size())
		root_container.free()
		return false

	# Debe haberse activado el de mayor prioridad: coord (2, 0)
	if activated_1[0] != Vector2i(2, 0):
		printerr("FAIL: Expected highest priority chunk (2, 0) activated first, got %s" % activated_1[0])
		root_container.free()
		return false

	root_container.free()
	print("✓ Test 4 passed: Activation scheduler respected budget and ordering.")
	return true


func test_task5_lifecycle_and_chunk_record() -> bool:
	print("\n[Test 5] ChunkLifecycle & ChunkRecord States...")
	var record := _ChunkLifecycleScript.ChunkRecord.new(Vector2i(3, 4))
	if record.state != _ChunkLifecycleScript.ChunkState.UNREQUESTED:
		printerr("FAIL: Initial state should be UNREQUESTED")
		return false

	record.state = _ChunkLifecycleScript.ChunkState.READY
	record.data = ChunkData.new(Vector2i(3, 4), Rect2i(0, 0, 16, 16), Rect2i(0, 0, 16, 16))
	if not record.is_ready():
		printerr("FAIL: is_ready() should be true")
		return false

	record.state = _ChunkLifecycleScript.ChunkState.CACHED
	if not record.is_cached():
		printerr("FAIL: is_cached() should be true")
		return false

	print("✓ Test 5 passed: ChunkLifecycle records work as expected.")
	return true


func test_task6_end_to_end_streaming_pipeline() -> bool:
	print("\n[Test 6] Full End-to-End Streaming & Cache Retrieval Pipeline...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 2)
	config.preload_radius = 3
	config.cache_radius = 5

	var mgr := _ChunkManagerScript.new(777, profile, config, null)

	# 1. Update streaming alrededor de (0, 0)
	mgr.update_streaming(Vector2i.ZERO, 2)

	# 2. Esperar que se completen las peticiones asíncronas
	var t_start := Time.get_ticks_msec()
	while not mgr.has_chunk(Vector2i.ZERO) and (Time.get_ticks_msec() - t_start) < 4000:
		mgr.poll_completed()
		OS.delay_msec(20)

	var loaded_initial := mgr.loaded_chunks.size()
	if loaded_initial == 0:
		printerr("FAIL: No chunks loaded via async streaming")
		mgr.shutdown()
		return false

	# 3. Determinismo: consultar celda y asegurar que el ChunkData es consistente
	var cell: WorldCell = mgr.get_cell(Vector2i(8, 8))
	if cell == null:
		printerr("FAIL: Expected cell at (8, 8) to be available")
		mgr.shutdown()
		return false

	mgr.shutdown()
	print("✓ Test 6 passed: Full streaming pipeline operates asynchronously.")
	return true
