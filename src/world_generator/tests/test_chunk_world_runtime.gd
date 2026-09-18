extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _ChunkManagerScript = preload("res://src/world_generator/chunks/chunk_manager.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 6: TEST DE RUNTIME CHUNKWORLD + CHUNKMANAGER")
	print("==================================================")

	var seed_val := 424242
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Test ChunkManager: determine_required_chunks & Lifecycle
	# -------------------------------------------------------------------------
	print("[1/5] Verificando ChunkManager y cálculo de vecindades...")
	var manager := _ChunkManagerScript.new(seed_val, profile, config)
	var req_3x3 := manager.determine_required_chunks(Vector2i(0, 0), 1)

	assert(req_3x3.size() == 9, "Radio 1 debe generar exactamente 9 chunks (3x3)")
	assert(req_3x3.has(Vector2i(-1, -1)), "Debe incluir cuadrante negativo (-1, -1)")
	assert(req_3x3.has(Vector2i(0, 0)), "Debe incluir centro (0, 0)")
	assert(req_3x3.has(Vector2i(1, 1)), "Debe incluir cuadrante positivo (1, 1)")
	print("      -> determine_required_chunks OK: 9 chunks en 3x3 (-1,-1 a 1,1).")

	# -------------------------------------------------------------------------
	# 2. Generar Hidrología Regional Compartida y Cargar Área 3x3 en ChunkWorld
	# -------------------------------------------------------------------------
	print("[2/5] Inicializando ChunkWorld y cargando área 3x3...")
	var shared_hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	assert(shared_hydro != null, "Hidrología regional compartida no debe ser null")

	var chunk_world := _ChunkWorldScript.new()
	root.add_child(chunk_world)
	chunk_world.initialize(seed_val, profile, config, shared_hydro)

	# Carga explícita inicial 3x3 centrada en (0, 0)
	chunk_world.load_initial_area(Vector2i(0, 0), 1)

	var loaded_coords := chunk_world.get_loaded_chunk_coords()
	assert(loaded_coords.size() == 9, "ChunkWorld debe tener exactamente 9 chunks cargados, tiene: %d" % loaded_coords.size())
	assert(chunk_world.chunk_views.size() == 9, "ChunkWorld debe tener 9 vistas 3D cargadas")

	for coord in req_3x3:
		assert(chunk_world.get_chunk(coord) != null, "Chunk %s debe estar cargado" % str(coord))
		var chunk_data: ChunkData = chunk_world.get_chunk(coord)
		assert(chunk_data.cells.size() == 256, "Chunk %s debe tener 256 celdas netas tras trim" % str(coord))

	print("      -> ChunkWorld inicializado con éxito: 9 chunks en memoria y en árbol 3D.")

	# -------------------------------------------------------------------------
	# 3. Resolución Continua de Celdas (Posición 3D y World Grid)
	# -------------------------------------------------------------------------
	print("[3/5] Verificando resolución de celdas y mapeo espacial 3D...")

	# Celda en el origen
	var cell_origin := chunk_world.get_cell_at_world_pos(Vector2i(0, 0))
	assert(cell_origin != null, "Celda en (0,0) debe existir")
	assert(cell_origin.position == Vector2i(0, 0), "Posición de celda debe coincidir")

	# Celda en cuadrante negativo (chunk -1, -1)
	var cell_neg := chunk_world.get_cell_at_world_pos(Vector2i(-5, -7))
	assert(cell_neg != null, "Celda en cuadrante negativo (-5, -7) debe existir")
	assert(cell_neg.position == Vector2i(-5, -7), "Posición de celda negativa correcta")

	# Resolución a partir de coordenadas 3D del Player / Target
	var player_pos := Vector3(18.5, 0.0, 22.3)  # Pertenece al chunk (1, 1) pues 18/16 = 1, 22/16 = 1
	var active_c := chunk_world.update_active_chunk_from_position(player_pos)
	assert(active_c == Vector2i(1, 1), "Posición 3D (18.5, 22.3) debe mapear a chunk (1, 1), dio: %s" % str(active_c))

	var cell_player := chunk_world.get_cell_at_position_3d(player_pos)
	assert(cell_player != null, "Debe resolver WorldCell bajo posición 3D del jugador")
	assert(cell_player.position == Vector2i(18, 22), "Debe corresponder a celda discreta (18, 22)")
	print("      -> Resolución espacial continua OK (soporta coordenadas positivas y negativas).")

	# -------------------------------------------------------------------------
	# 4. Verificación de Continuidad Geométrica en Costuras Internas 3x3
	# -------------------------------------------------------------------------
	print("[4/5] Verificando continuidad geométrica en costuras internas 3x3...")
	# Costura vertical x = -1 (chunk -1,0) <-> x = 0 (chunk 0,0)
	var max_step_x0 := 0.0
	for y in range(0, 16):
		var c_left := chunk_world.get_cell_at_world_pos(Vector2i(-1, y))
		var c_right := chunk_world.get_cell_at_world_pos(Vector2i(0, y))
		assert(c_left != null and c_right != null, "Celdas de costura x=-1..0 deben existir")
		var step := absf(c_left.height - c_right.height)
		if step > max_step_x0:
			max_step_x0 = step

	# Costura horizontal y = -1 (chunk 0,-1) <-> y = 0 (chunk 0,0)
	var max_step_y0 := 0.0
	for x in range(0, 16):
		var c_top := chunk_world.get_cell_at_world_pos(Vector2i(x, -1))
		var c_bot := chunk_world.get_cell_at_world_pos(Vector2i(x, 0))
		assert(c_top != null and c_bot != null, "Celdas de costura y=-1..0 deben existir")
		var step := absf(c_top.height - c_bot.height)
		if step > max_step_y0:
			max_step_y0 = step

	print("      -> Max desnivel en costura x=-1<->0: %.4f m" % max_step_x0)
	print("      -> Max desnivel en costura y=-1<->0: %.4f m" % max_step_y0)
	assert(max_step_x0 < 2.5, "Continuidad C0 respetada en costura x=0")
	assert(max_step_y0 < 2.5, "Continuidad C0 respetada en costura y=0")

	# -------------------------------------------------------------------------
	# 5. Desplazamiento y Ciclo de Vida: Unload y Carga Dinámica
	# -------------------------------------------------------------------------
	print("[5/5] Probando desplazamiento de foco y descarga de chunks...")
	# Mover el foco al chunk (1, 0) con radio 1:
	# Chunks requeridos: x in [0, 2], y in [-1, 1]
	# Se deben descargar los chunks con x = -1: (-1,-1), (-1,0), (-1,1)
	# Se deben cargar los chunks con x = 2: (2,-1), (2,0), (2,1)
	chunk_world.load_initial_area(Vector2i(1, 0), 1)

	var new_loaded := chunk_world.get_loaded_chunk_coords()
	assert(new_loaded.size() == 9, "Debe mantener exactamente 9 chunks cargados")
	assert(not chunk_world.chunk_manager.has_chunk(Vector2i(-1, 0)), "Chunk (-1, 0) debió ser descargado")
	assert(not chunk_world.chunk_manager.has_chunk(Vector2i(-1, -1)), "Chunk (-1, -1) debió ser descargado")
	assert(not chunk_world.chunk_manager.has_chunk(Vector2i(-1, 1)), "Chunk (-1, 1) debió ser descargado")

	assert(chunk_world.chunk_manager.has_chunk(Vector2i(2, 0)), "Chunk (2, 0) debe estar cargado")
	assert(chunk_world.chunk_manager.has_chunk(Vector2i(2, -1)), "Chunk (2, -1) debe estar cargado")
	assert(chunk_world.chunk_manager.has_chunk(Vector2i(2, 1)), "Chunk (2, 1) debe estar cargado")

	# El chunk (0, 0) se mantuvo en memoria
	assert(chunk_world.chunk_manager.has_chunk(Vector2i(0, 0)), "Chunk (0, 0) debió conservarse cargado")
	print("      -> Descarga y carga selectiva verificada correctamente.")

	print("\n==================================================")
	print(" BLOQUE 6: TODOS LOS TESTS DE RUNTIME PASARON OK!")
	print("==================================================\n")
	quit(0)
