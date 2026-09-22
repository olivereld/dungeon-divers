extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	print("==================================================")
	print(" TEST: STREAMING CON MÍNIMO 12 CHUNKS CARGADOS")
	print("==================================================")

	var profile := _AutumnForestWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1, 2)
	var seed_val := 12345
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	var root := Node3D.new()
	var chunk_world: ChunkWorld = _ChunkWorldScript.new()
	root.add_child(chunk_world)

	chunk_world.initialize(seed_val, profile, config, shared_hydro, 2)
	chunk_world.load_initial_area(Vector2i.ZERO, 2)

	var init_count: int = chunk_world.chunk_manager.loaded_chunks.size()
	print("[1/3] Estado inicial en (0, 0): %d chunks cargados." % init_count)
	assert(init_count >= 12, "Debe haber al menos 12 chunks cargados inicialmente (se esperan 13)")

	print("[2/3] Vinculando jugador y simulando avance paso a paso...")
	var player = _PlayerTestScript.new()
	root.add_child(player)
	chunk_world.set_tracked_target(player)

	# Simular movimiento continuo hacia adelante (atravesando varios chunks: X = 0 -> 16 -> 32 -> 48 -> 64)
	var steps := [
		Vector3(8.0, 10.0, 8.0),   # Chunk (0, 0)
		Vector3(24.0, 10.0, 8.0),  # Chunk (1, 0)
		Vector3(40.0, 10.0, 8.0),  # Chunk (2, 0)
		Vector3(56.0, 10.0, 8.0),  # Chunk (3, 0)
		Vector3(72.0, 10.0, 8.0),  # Chunk (4, 0) - Cruza a nueva macro-región
		Vector3(88.0, 10.0, 8.0),  # Chunk (5, 0)
	]

	var step_idx := 0
	for pos in steps:
		step_idx += 1
		player.position = pos
		chunk_world.update_player_streaming()
		chunk_world.flush_async_queue()

		var loaded_now: int = chunk_world.chunk_manager.loaded_chunks.size()
		print("      Paso %d -> Jugador en %s, Chunk activo: %s, Chunks cargados: %d" % [
			step_idx, str(pos), str(chunk_world.active_chunk), loaded_now
		])
		assert(loaded_now >= 12, "El conteo de chunks NUNCA debe caer por debajo de 12 mientras se avanza! (actual: %d)" % loaded_now)

	print("[3/3] Simulación de movimiento diagonal (X y Z simultáneos)...")
	var diag_steps := [
		Vector3(88.0, 10.0, 24.0),  # Chunk (5, 1)
		Vector3(104.0, 10.0, 40.0), # Chunk (6, 2)
		Vector3(120.0, 10.0, 56.0), # Chunk (7, 3)
	]

	for pos in diag_steps:
		step_idx += 1
		player.position = pos
		chunk_world.update_player_streaming()
		chunk_world.flush_async_queue()

		var loaded_now: int = chunk_world.chunk_manager.loaded_chunks.size()
		print("      Paso %d (diag) -> Jugador en %s, Chunk activo: %s, Chunks cargados: %d" % [
			step_idx, str(pos), str(chunk_world.active_chunk), loaded_now
		])
		assert(loaded_now >= 12, "El conteo de chunks NUNCA debe caer por debajo de 12 en avance diagonal! (actual: %d)" % loaded_now)

	print("==================================================")
	print(" TEST STREAMING 12 CHUNKS: EXITOSO (Mínimo 12 siempre cargados)")
	print("==================================================")
	quit(0)
