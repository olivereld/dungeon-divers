extends SceneTree

## BLOQUE 8 — Test de Integración: Generación Asíncrona + Streaming sin Bloquear el Frame
## Valida la equivalencia determinista (async == sync), el ciclo de vida con scheduler,
## el descarte de resultados obsoletos mediante tokens, la convergencia loaded == required,
## y la integridad de mallas y colisiones en el Main Thread.

const _ChunkGenerationSchedulerScript = preload("res://src/world_generator/chunks/chunk_generation_scheduler.gd")
const _ChunkWorldIntegrationScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 8: TEST STREAMING ASINCRONO Y DETERMINISMO")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)
	var shared_hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	# -------------------------------------------------------------------------
	# [1] Equivalencia determinista: async == sync
	# -------------------------------------------------------------------------
	print("[1/7] Verificando equivalencia determinista (async == sync)...")
	var test_coord := Vector2i(2, 2)
	# 1.1 Síncrono
	var sync_chunk := _WorldPipelineScript.generate_chunk(seed_val, test_coord, profile, config, shared_hydro)

	# 1.2 Asíncrono vía Scheduler
	var scheduler := _ChunkGenerationSchedulerScript.new()
	scheduler.request_chunk(test_coord, seed_val, profile, config, shared_hydro, 100)

	var async_chunk: ChunkData = null
	var start_wait := Time.get_ticks_msec()
	while async_chunk == null and (Time.get_ticks_msec() - start_wait < 5000):
		var completed: Array = scheduler.poll_completed()
		for item in completed:
			if item["coord"] == test_coord:
				async_chunk = item["chunk_data"] as ChunkData
				break
		if async_chunk == null:
			OS.delay_msec(2)

	scheduler.shutdown()

	assert(async_chunk != null, "Generación async debe entregar ChunkData")
	assert(sync_chunk.cells.size() == async_chunk.cells.size(), "Debe tener mismo número de celdas (256)")

	var max_h_diff := 0.0
	for pos in sync_chunk.cells:
		var c_sync: WorldCell = sync_chunk.cells[pos]
		var c_async: WorldCell = async_chunk.cells[pos]
		assert(c_async != null, "Celda %s debe existir en chunk async" % str(pos))
		var diff := absf(c_sync.height - c_async.height)
		if diff > max_h_diff:
			max_h_diff = diff
		assert(c_sync.is_walkable == c_async.is_walkable, "is_walkable debe coincidir")
		assert(c_sync.slope_category == c_async.slope_category, "slope_category debe coincidir")
		assert(absf(c_sync.normalized_height - c_async.normalized_height) < 0.000001, "normalized_height debe coincidir")
		assert(absf(c_sync.hydraulic_influence - c_async.hydraulic_influence) < 0.000001, "hydraulic_influence debe coincidir")

	assert(max_h_diff < 0.000001, "Altura debe ser 100%% idéntica entre sync y async (max diff: %s)" % str(max_h_diff))
	assert(sync_chunk.vegetation.size() == async_chunk.vegetation.size(), "Vegetación debe ser idéntica")
	print("      -> async == sync OK: 100%% idéntico (max h diff: %s m, vegetación: %d items)." % [
		str(max_h_diff), async_chunk.vegetation.size()
	])

	# -------------------------------------------------------------------------
	# Inicializar Escena de Integración
	# -------------------------------------------------------------------------
	var scene = _ChunkWorldIntegrationScript.new()
	scene.world_seed = seed_val
	root.add_child(scene)
	if scene.chunk_world == null:
		scene._ready()

	var world: ChunkWorld = scene.chunk_world
	var player: CharacterBody3D = scene.player
	var manager: WorldChunkManager = world.chunk_manager

	# -------------------------------------------------------------------------
	# [2] Cruce X con streaming asíncrono
	# -------------------------------------------------------------------------
	print("[2/7] Probando cruce continuo en X (16, 32, 48) con streaming async...")
	var x_targets := [16.0, 32.0, 48.0]
	for tx in x_targets:
		# Mover jugador justo después de la costura
		player.position = Vector3(tx + 0.5, 20.0, 8.0)
		world.update_player_streaming()
		# Procesar cola async
		world.flush_async_queue()

		var expected_cx := floori((tx + 0.5) / 16.0)
		_verify_convergence(world, Vector2i(expected_cx, 0), "Cruce X=%.0f" % tx)

	print("      -> Cruce X completado con éxito en todos los umbrales.")

	# -------------------------------------------------------------------------
	# [3] Cruce Z con streaming asíncrono
	# -------------------------------------------------------------------------
	print("[3/7] Probando cruce continuo en Z (16, 32, 48) con streaming async...")
	# Regresar a x=8.0 y cruzar Z
	player.position = Vector3(8.0, 20.0, 8.0)
	world.update_player_streaming()
	world.flush_async_queue()

	var z_targets := [16.0, 32.0, 48.0]
	for tz in z_targets:
		player.position = Vector3(8.0, 20.0, tz + 0.5)
		world.update_player_streaming()
		world.flush_async_queue()

		var expected_cz := floori((tz + 0.5) / 16.0)
		_verify_convergence(world, Vector2i(0, expected_cz), "Cruce Z=%.0f" % tz)

	print("      -> Cruce Z completado con éxito en todos los umbrales.")

	# -------------------------------------------------------------------------
	# [4] Descarte de resultados obsoletos (Invalidación por token)
	# -------------------------------------------------------------------------
	print("[4/7] Probando descarte de peticiones obsoletas ante movimiento rápido...")
	# Mover el foco muy rápido a (10, 0), sin dar tiempo a que los intermedios se estabilicen
	player.position = Vector3(160.0, 20.0, 0.0)  # Chunk (10, 0)
	world.update_player_streaming()
	# Inmediatamente mover a (-5, -5)
	player.position = Vector3(-80.0, 20.0, -80.0)  # Chunk (-5, -5)
	world.update_player_streaming()

	world.flush_async_queue()

	# Verificar que el chunk intermedio (10, 0) NO fue integrado a loaded_chunks
	assert(not world.chunk_manager.has_chunk(Vector2i(10, 0)), "Chunk obsoleto (10,0) debió ser descartado")
	assert(not world.chunk_views.has(Vector2i(10, 0)), "Vista de chunk obsoleto (10,0) no debe existir")
	_verify_convergence(world, Vector2i(-5, -5), "Movimiento rápido a (-5, -5)")
	print("      -> Peticiones obsoletas descartadas correctamente por token.")

	# -------------------------------------------------------------------------
	# [5] Convergencia estricta: loaded == required (9 chunks)
	# -------------------------------------------------------------------------
	print("[5/7] Verificando invariante de convergencia loaded == required...")
	_verify_convergence(world, world.active_chunk, "Verificación de convergencia")
	print("      -> loaded == required verificado (exactamente 9 chunks en memoria y 9 vistas 3D).")

	# -------------------------------------------------------------------------
	# [6] Verificación de costuras a 0.0 metros en chunks async
	# -------------------------------------------------------------------------
	print("[6/7] Verificando que las costuras permanecen en 0.0 metros en chunks async...")
	# Regresar a (0, 0)
	player.position = Vector3(8.0, 20.0, 8.0)
	world.update_player_streaming()
	world.flush_async_queue()

	var c0: ChunkData = world.get_chunk(Vector2i(0, 0))
	var c1: ChunkData = world.get_chunk(Vector2i(1, 0))
	assert(c0 != null and c1 != null, "Chunks (0,0) y (1,0) deben estar cargados")

	for y in range(16):
		var h0: float = c0.get_cell_or_seam(Vector2i(16, y)).height
		var h1: float = c1.get_cell_or_seam(Vector2i(16, y)).height
		assert(absf(h0 - h1) < 0.00001, "Costura x=16 debe coincidir con 0.0 de diferencia")

	print("      -> Costuras selladas con 0.0 m de diferencia.")

	# -------------------------------------------------------------------------
	# [7] Verificación de colisión funcional
	# -------------------------------------------------------------------------
	print("[7/7] Verificando existencia y solidez de colisión en Main Thread...")
	for coord in world.get_loaded_chunk_coords():
		var view: Node3D = world.chunk_views[coord]
		var col_body: StaticBody3D = view.get_node_or_null("TerrainCollision") as StaticBody3D
		assert(col_body != null, "Chunk %s debe tener StaticBody3D" % str(coord))
		var shape_node: CollisionShape3D = null
		for child in col_body.get_children():
			if child is CollisionShape3D:
				shape_node = child as CollisionShape3D
				break
		assert(shape_node != null and shape_node.shape != null, "Chunk %s debe tener colisión configurada" % str(coord))

	print("      -> Colisiones presentes y sólidas en todos los chunks.")

	# Cierre limpio de threads
	world.shutdown()

	print("\n==================================================")
	print(" BLOQUE 8: TODOS LOS TESTS ASINCRONOS PASARON OK!")
	print("==================================================")
	quit(0)


func _verify_convergence(world: ChunkWorld, expected_center: Vector2i, label: String) -> void:
	assert(world.active_chunk == expected_center, "%s: active_chunk esperado %s, actual %s" % [
		label, str(expected_center), str(world.active_chunk)
	])

	var manager: WorldChunkManager = world.chunk_manager
	var req: Array[Vector2i] = manager.determine_required_chunks(expected_center, 1)
	var loaded: Array[Vector2i] = world.get_loaded_chunk_coords()

	assert(loaded.size() == 9, "%s: Esperados 9 chunks cargados, hay %d" % [label, loaded.size()])
	assert(world.chunk_views.size() == 9, "%s: Esperadas 9 vistas 3D, hay %d" % [label, world.chunk_views.size()])

	for r in req:
		assert(manager.has_chunk(r), "%s: Chunk requerido %s no esta cargado" % [label, str(r)])
		assert(world.chunk_views.has(r), "%s: Falta vista 3D para chunk %s" % [label, str(r)])

	for l in loaded:
		assert(req.has(l), "%s: Chunk cargado %s no es requerido" % [label, str(l)])
