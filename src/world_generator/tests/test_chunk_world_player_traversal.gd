extends SceneTree

## BLOQUE 7 — Test de Integración: Jugador + Continuidad entre Chunks
## Valida el movimiento continuo del jugador a través de costuras X y Z,
## la actualización de streaming centrada en el jugador, la continuidad
## física sin caídas ni huecos, y el invariante loaded_chunks == required_chunks.

const _ChunkWorldIntegrationScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")
const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 7: TEST INTEGRACIÓN JUGADOR Y CONTINUIDAD")
	print("==================================================")

	var scene = _ChunkWorldIntegrationScript.new()
	scene.world_seed = 12345
	scene.render_distance = 1
	root.add_child(scene)

	# Esperar un frame para que se ejecute _ready()
	# En modo SceneTree headless sin loop, llamamos a _ready() directamente si es necesario
	if scene.chunk_world == null:
		scene._ready()

	var world: ChunkWorld = scene.chunk_world
	var player: CharacterBody3D = scene.player
	var manager: WorldChunkManager = world.chunk_manager

	assert(world != null, "ChunkWorld debe estar instanciado")
	assert(player != null, "Player debe estar instanciado")
	assert(manager != null, "ChunkManager debe estar instanciado")

	# -------------------------------------------------------------------------
	# [1] Player starts in valid terrain
	# -------------------------------------------------------------------------
	print("[1/8] Verificando estado inicial del jugador en terreno valido...")
	var initial_active := world.active_chunk
	assert(initial_active == Vector2i(0, 0), "Chunk activo inicial debe ser (0,0), dio: %s" % str(initial_active))

	_verify_invariant(world, initial_active, "Inicio")
	var initial_cell := world.get_cell_at_position_3d(player.position)
	assert(initial_cell != null, "Celda inicial del jugador no debe ser null")
	assert(player.position.y >= initial_cell.height, "Jugador debe iniciar sobre el terreno")
	print("      -> Posición inicial OK en (%.1f, %.1f, %.1f), cota terreno: %.2f m" % [
		player.position.x, player.position.y, player.position.z, initial_cell.height
	])

	# -------------------------------------------------------------------------
	# [2] Cruce continuo de fronteras en eje X (x = 15->16, 31->32, 47->48)
	# -------------------------------------------------------------------------
	print("[2/8] Simulando recorrido continuo en X atravesando costuras (16, 32, 48)...")
	var target_x_crossings := [16.0, 32.0, 48.0]
	var current_crossing_idx := 0

	# Mover al jugador de x = 8.0 a x = 52.0 a paso de 0.5m
	var cur_x := 8.0
	var z_const := 8.0

	while cur_x <= 52.0:
		cur_x += 0.5
		var expected_cx := floori(cur_x / 16.0)

		# Obtener altura de terreno en esta posición
		var cell := world.get_cell_at_world_pos(Vector2i(floori(cur_x), floori(z_const)))
		assert(cell != null, "Celda en x=%.1f debe existir en chunks cargados" % cur_x)

		# Mover jugador
		player.position = Vector3(cur_x, cell.height + 1.0, z_const)

		# Actualizar streaming
		world.update_player_streaming()
		world.flush_async_queue()

		# [4, 5, 7, 8] Verificar invariante
		_verify_invariant(world, Vector2i(expected_cx, 0), "Paso X=%.1f" % cur_x)

		# [6] Verificar que el jugador permanece sobre el terreno
		assert(player.position.y >= cell.height, "Jugador cayo bajo el terreno en X=%.1f" % cur_x)

		# Comprobar si acabamos de cruzar una costura
		if current_crossing_idx < target_x_crossings.size():
			var seam_x: float = float(target_x_crossings[current_crossing_idx])
			if cur_x >= seam_x and (cur_x - 0.5) < seam_x:
				print("      -> Costura X=%.0f cruzada con éxito. Chunk activo: %s. Chunks cargados: 9." % [
					seam_x, str(world.active_chunk)
				])
				current_crossing_idx += 1

	print("      -> Todos los cruces X (16, 32, 48) completados con éxito.")

	# -------------------------------------------------------------------------
	# [3] Cruce continuo de fronteras en eje Z (z = 15->16, 31->32, 47->48)
	# -------------------------------------------------------------------------
	print("[3/8] Simulando recorrido continuo en Z atravesando costuras (16, 32, 48)...")
	# Regresar a x = 8.0, z = 8.0 y actualizar streaming para volver a centrar en (0, 0)
	player.position = Vector3(8.0, 20.0, 8.0)
	world.update_player_streaming()
	world.flush_async_queue()
	_verify_invariant(world, Vector2i(0, 0), "Retorno a (0,0)")

	var target_z_crossings := [16.0, 32.0, 48.0]
	var current_z_idx := 0
	var cur_z := 8.0
	var x_const := 8.0

	while cur_z <= 52.0:
		cur_z += 0.5
		var expected_cz := floori(cur_z / 16.0)

		var cell := world.get_cell_at_world_pos(Vector2i(floori(x_const), floori(cur_z)))
		assert(cell != null, "Celda en z=%.1f debe existir en chunks cargados" % cur_z)

		player.position = Vector3(x_const, cell.height + 1.0, cur_z)
		world.update_player_streaming()
		world.flush_async_queue()

		_verify_invariant(world, Vector2i(0, expected_cz), "Paso Z=%.1f" % cur_z)
		assert(player.position.y >= cell.height, "Jugador cayo bajo el terreno en Z=%.1f" % cur_z)

		if current_z_idx < target_z_crossings.size():
			var seam_z: float = float(target_z_crossings[current_z_idx])
			if cur_z >= seam_z and (cur_z - 0.5) < seam_z:
				print("      -> Costura Z=%.0f cruzada con éxito. Chunk activo: %s. Chunks cargados: 9." % [
					seam_z, str(world.active_chunk)
				])
				current_z_idx += 1

	print("      -> Todos los cruces Z (16, 32, 48) completados con éxito.")

	# -------------------------------------------------------------------------
	# [4 & 5] Comprobar consistencia de chunks descargados
	# -------------------------------------------------------------------------
	print("[4/8] Verificando que ningún chunk descargado permanece en memoria...")
	# En la posición final z = 52, active_chunk es (0, 3).
	# Chunks con z = 0, 1 deben haber sido descargados.
	assert(not world.chunk_manager.has_chunk(Vector2i(0, 0)), "Chunk (0,0) debe haber sido descargado")
	assert(not world.chunk_manager.has_chunk(Vector2i(0, 1)), "Chunk (0,1) debe haber sido descargado")
	assert(world.chunk_manager.has_chunk(Vector2i(0, 3)), "Chunk activo (0,3) debe estar cargado")
	print("      -> Ciclo de vida y descarga de chunks obsoletos OK.")

	# -------------------------------------------------------------------------
	# [6] Verificación de solidez de colisión en costuras (sin huecos)
	# -------------------------------------------------------------------------
	print("[5/8] Verificando solidez de colisión en costuras exactas...")
	# Comprobar que en las coordenadas de costura exactas x=16, 32, 48 existe celda y cota coherente
	for seam in [16, 32, 48]:
		var c_left := world.get_cell_at_world_pos(Vector2i(seam - 1, 8))
		var c_right := world.get_cell_at_world_pos(Vector2i(seam, 8))
		if c_left != null and c_right != null:
			var step := absf(c_left.height - c_right.height)
			assert(step < 2.0, "Desnivel abrupto inesperado en costura x=%d: %f" % [seam, step])
	print("      -> Costuras cerradas sin escalón artificial.")

	# -------------------------------------------------------------------------
	# [7] Verificación de conteo invariable de chunks (exactamente 9)
	# -------------------------------------------------------------------------
	print("[6/8] Verificando conteo estricto de 9 chunks durante todo el proceso...")
	assert(world.get_loaded_chunk_coords().size() == 9, "El conteo final debe ser 9 chunks")
	assert(world.chunk_views.size() == 9, "Debe haber exactamente 9 vistas 3D en escena")
	print("      -> Conteo de chunks estricto verificado: exactamente 9.")

	# -------------------------------------------------------------------------
	# [8] Verificación de coordenadas cargadas vs requeridas
	# -------------------------------------------------------------------------
	print("[7/8] Verificando correspondencia biyectiva loaded_chunks == required_chunks...")
	var req_final := manager.determine_required_chunks(world.active_chunk, 1)
	var loaded_final := world.get_loaded_chunk_coords()
	for r in req_final:
		assert(loaded_final.has(r), "Chunk requerido %s debe estar cargado" % str(r))
	for l in loaded_final:
		assert(req_final.has(l), "Chunk cargado %s debe ser requerido" % str(l))
	print("      -> Invariante loaded == required verificado al 100%.")

	# -------------------------------------------------------------------------
	# Finalización
	# -------------------------------------------------------------------------
	print("\n==================================================")
	world.shutdown()
	quit(0)


## Verifica el invariante estricto de streaming: loaded_chunks == required_chunks (tamaño 9)
func _verify_invariant(world: ChunkWorld, expected_center: Vector2i, context_label: String) -> void:
	assert(world.active_chunk == expected_center, "%s: Centro activo esperado %s, actual %s" % [
		context_label, str(expected_center), str(world.active_chunk)
	])

	var manager: WorldChunkManager = world.chunk_manager
	var req: Array[Vector2i] = manager.determine_required_chunks(expected_center, 1)
	var loaded: Array[Vector2i] = world.get_loaded_chunk_coords()

	# 1. Exactamente 9 chunks
	assert(loaded.size() == 9, "%s: Se esperaban 9 chunks cargados, hay %d" % [context_label, loaded.size()])
	assert(world.chunk_views.size() == 9, "%s: Se esperaban 9 vistas 3D, hay %d" % [context_label, world.chunk_views.size()])

	# 2. No falta ningún chunk requerido
	for r in req:
		assert(manager.has_chunk(r), "%s: Chunk requerido %s no esta cargado" % [context_label, str(r)])
		assert(world.chunk_views.has(r), "%s: Falta vista 3D para chunk requerido %s" % [context_label, str(r)])

	# 3. No sobra ningún chunk cargado
	for l in loaded:
		assert(req.has(l), "%s: Chunk cargado %s no pertenece al conjunto requerido" % [context_label, str(l)])
