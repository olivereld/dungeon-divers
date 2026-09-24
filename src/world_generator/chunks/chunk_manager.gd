class_name WorldChunkManager
extends RefCounted

## Gestor desacoplado del ciclo de vida (lifecycle), caché y streaming de chunks.
## Orquesta la generación asíncrona mediante ChunkGenerationScheduler (BLOQUE 8),
## manteniendo estricta autoridad sobre required_chunks y controlando el estado
## y descarte de peticiones obsoletas mediante tokens.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _ChunkGenerationSchedulerScript = preload("res://src/world_generator/chunks/chunk_generation_scheduler.gd")
const _DungeonPOIGeneratorScript = preload("res://src/world_generator/poi/dungeon_poi_generator.gd")

signal chunk_loaded(coord: Vector2i, chunk_data: ChunkData)
signal chunk_unloaded(coord: Vector2i)

enum ChunkState {
	QUEUED,
	GENERATING,
	LOADED
}

var seed_val: int = 0
var profile: WorldProfile = null
var config: ChunkConfig = null
var shared_hydrology: HydrologyResult = null

## Chunks actualmente cargados e integrados en memoria (Vector2i -> ChunkData)
var loaded_chunks: Dictionary = {}

## Estado de cada chunk en el pipeline (Vector2i -> ChunkState)
var chunk_states: Dictionary = {}

## Mapeo de tokens activos por coordenada (Vector2i -> int)
var chunk_tokens: Dictionary = {}

## Conjunto de coordenadas actualmente requeridas por el streaming (Vector2i -> bool)
var current_required_chunks: Dictionary = {}

## Scheduler de generación asíncrona en worker thread
var scheduler: RefCounted = null
var poi_generator: RefCounted = null
var _evaluated_pois: Dictionary = {} # Vector2i (macro_coord) -> DungeonPOI or null

var _next_token: int = 1
var _generated_macro_regions: Dictionary = {}

# Telemetría de streaming y scheduling (BLOQUE 9 / BLOQUE 12)
var stats_requested: int = 0
var stats_generated: int = 0
var stats_discarded: int = 0
var stats_loaded: int = 0
var stats_unloaded: int = 0
var stats_peak_pending: int = 0
var stats_queue_times: Array[float] = []
var stats_gen_times: Array[float] = []
var stats_latencies: Array[float] = []


func reset_stats() -> void:
	stats_requested = 0
	stats_generated = 0
	stats_discarded = 0
	stats_loaded = 0
	stats_unloaded = 0
	stats_peak_pending = 0
	stats_queue_times.clear()
	stats_gen_times.clear()
	stats_latencies.clear()


func _init(
	p_seed: int = 0,
	p_profile: WorldProfile = null,
	p_config: ChunkConfig = null,
	p_shared_hydro: HydrologyResult = null
) -> void:
	seed_val = p_seed
	profile = p_profile if p_profile != null else TaigaWorldProfile.new()
	config = p_config if p_config != null else ChunkConfig.new()
	shared_hydrology = p_shared_hydro
	if shared_hydrology != null:
		_generated_macro_regions[Vector2i.ZERO] = true
	scheduler = _ChunkGenerationSchedulerScript.new()


func _ensure_macro_hydrology(coord: Vector2i) -> void:
	var macro_w: int = maxi(profile.width, 64) if profile != null else 64
	var macro_h: int = maxi(profile.height, 64) if profile != null else 64
	var chunk_sz: int = config.chunk_size if config != null else 16
	var margin: int = config.generation_margin if config != null else 1
	var gen_bounds: Rect2i = ChunkCoord.get_generation_bounds(coord, chunk_sz, margin)

	var min_mx: int = int(floor(float(gen_bounds.position.x) / float(macro_w)))
	var max_mx: int = int(floor(float(gen_bounds.end.x - 1) / float(macro_w)))
	var min_my: int = int(floor(float(gen_bounds.position.y) / float(macro_h)))
	var max_my: int = int(floor(float(gen_bounds.end.y - 1) / float(macro_h)))

	for my in range(min_my, max_my + 1):
		for mx in range(min_mx, max_mx + 1):
			var m_coord := Vector2i(mx, my)
			if _generated_macro_regions.has(m_coord):
				continue
			_generated_macro_regions[m_coord] = true
			var reg_origin := Vector2i(mx * macro_w, my * macro_h)
			var reg_hydro := _WorldPipelineScript.generate_regional_hydrology(seed_val, profile, reg_origin)
			if shared_hydrology == null:
				shared_hydrology = reg_hydro
			else:
				shared_hydrology.merge(reg_hydro, profile.cell_size if profile != null else 1.0)


## Calcula la lista de coordenadas requeridas para un radio rectangular.
func determine_required_chunks(center_coord: Vector2i, radius: int = 1) -> Array[Vector2i]:
	var required: Array[Vector2i] = []
	var use_circular: bool = (config != null and config.circular_streaming and radius >= 2)
	var r_sq := float(radius) * float(radius) + 0.1
	for cy in range(center_coord.y - radius, center_coord.y + radius + 1):
		for cx in range(center_coord.x - radius, center_coord.x + radius + 1):
			if use_circular:
				var dx := float(cx - center_coord.x)
				var dy := float(cy - center_coord.y)
				if (dx * dx + dy * dy) > r_sq:
					continue
			required.append(Vector2i(cx, cy))
	return required


func has_chunk(coord: Vector2i) -> bool:
	return loaded_chunks.has(coord)


func get_chunk(coord: Vector2i) -> ChunkData:
	return loaded_chunks.get(coord, null)


func get_loaded_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for k in loaded_chunks.keys():
		coords.append(k)
	return coords


## Carga síncronamente un chunk si no está en memoria usando WorldPipeline.
## Utilizado para compatibilidad directa o inicializaciones inmediatas.
func load_chunk(coord: Vector2i) -> ChunkData:
	if loaded_chunks.has(coord):
		return loaded_chunks[coord]

	_ensure_macro_hydrology(coord)
	var chunk_data := _WorldPipelineScript.generate_chunk(
		seed_val,
		coord,
		profile,
		config,
		shared_hydrology
	)

	loaded_chunks[coord] = chunk_data
	chunk_states[coord] = ChunkState.LOADED
	_attach_pois_to_chunk(chunk_data)
	chunk_loaded.emit(coord, chunk_data)
	return chunk_data


## Descarga un chunk si se encuentra en memoria o invalida su petición si está encolado.
func unload_chunk(coord: Vector2i) -> void:
	_next_token += 1
	chunk_tokens[coord] = _next_token
	if scheduler != null:
		scheduler.invalidate_token(coord, _next_token)

	chunk_states.erase(coord)

	if not loaded_chunks.has(coord):
		return

	loaded_chunks.erase(coord)
	stats_unloaded += 1
	chunk_unloaded.emit(coord)


## Actualiza los chunks requeridos por el streaming de forma asíncrona.
## Invalida peticiones obsoletas y encola las nuevas necesarias.
func update_streaming(center_coord: Vector2i, radius: int = -1) -> void:
	var r: int = (config.render_distance if (config != null and "render_distance" in config) else 2) if radius < 0 else radius
	var required_list := determine_required_chunks(center_coord, r)
	keep_loaded(required_list, center_coord, r)


## Sincroniza el conjunto de chunks requeridos:
## descarga los que salieron del área con histéresis y encola de forma asíncrona los que faltan.
func keep_loaded(required_coords: Array[Vector2i], center_coord: Vector2i = Vector2i.ZERO, radius: int = 2) -> void:
	current_required_chunks.clear()
	for c in required_coords:
		current_required_chunks[c] = true

	# Histéresis de descarga: si radius >= 2, conservamos chunks cercanos mientras se avanza
	# para garantizar que siempre haya al menos 12 chunks cargados.
	var use_hysteresis: bool = (radius >= 2 and config != null and config.unload_margin > 0.0)
	var unload_r: float = float(radius) + (config.unload_margin if config != null else 0.65)
	var unload_r_sq: float = unload_r * unload_r

	# 1. Identificar y descargar chunks LOADED que ya no se requieren
	var to_unload: Array[Vector2i] = []
	for c in loaded_chunks:
		if not current_required_chunks.has(c):
			if use_hysteresis:
				var dx: float = float(c.x - center_coord.x)
				var dy: float = float(c.y - center_coord.y)
				if (dx * dx + dy * dy) > unload_r_sq:
					to_unload.append(c)
			else:
				to_unload.append(c)

	for c in to_unload:
		unload_chunk(c)

	# 2. Cancelar peticiones encoladas que ya no se requieren
	var obsolete_pending: Array[Vector2i] = []
	for c in chunk_states:
		if not current_required_chunks.has(c) and chunk_states[c] != ChunkState.LOADED:
			obsolete_pending.append(c)

	for c in obsolete_pending:
		_next_token += 1
		chunk_tokens[c] = _next_token
		if scheduler != null:
			scheduler.invalidate_token(c, _next_token)
		chunk_states.erase(c)

	# 3. Encolar los nuevos chunks requeridos que no estén cargados ni solicitados
	for c in required_coords:
		if not has_chunk(c) and not chunk_states.has(c):
			_enqueue_chunk_generation(c)


## Extrae resultados completados del scheduler de forma NO BLOQUEANTE.
## Valida tokens y pertinencia antes de integrar cada chunk a loaded_chunks.
func poll_completed() -> Array[Vector2i]:
	if scheduler == null:
		return []

	var completed_items: Array = scheduler.poll_completed()
	var integrated: Array[Vector2i] = []

	for item in completed_items:
		var coord: Vector2i = item["coord"]
		var chunk_data: ChunkData = item["chunk_data"]
		var token: int = item["token"]

		stats_generated += 1

		var active_tok: int = chunk_tokens.get(coord, -1)

		# ¿Token vigente Y chunk aún requerido?
		if token == active_tok and current_required_chunks.has(coord):
			loaded_chunks[coord] = chunk_data
			chunk_states[coord] = ChunkState.LOADED
			stats_loaded += 1

			if item.has("queue_time_ms"):
				stats_queue_times.append(item["queue_time_ms"])
			if item.has("gen_time_ms"):
				stats_gen_times.append(item["gen_time_ms"])
			if item.has("enqueue_time_usec"):
				var lat_ms := float(Time.get_ticks_usec() - item["enqueue_time_usec"]) / 1000.0
				stats_latencies.append(lat_ms)

			_attach_pois_to_chunk(chunk_data)
			chunk_loaded.emit(coord, chunk_data)
			integrated.append(coord)
		else:
			# Descartar resultado obsoleto
			stats_discarded += 1
			if chunk_states.has(coord) and chunk_states[coord] != ChunkState.LOADED:
				chunk_states.erase(coord)

	return integrated


func _enqueue_chunk_generation(coord: Vector2i) -> void:
	_ensure_macro_hydrology(coord)
	_next_token += 1
	var token := _next_token
	chunk_tokens[coord] = token
	chunk_states[coord] = ChunkState.QUEUED
	stats_requested += 1
	stats_peak_pending = maxi(stats_peak_pending, chunk_states.size())
	if scheduler != null:
		scheduler.request_chunk(coord, seed_val, profile, config, shared_hydrology, token)


## Resuelve una celda mundial consultando el chunk correspondiente si está cargado.
func get_cell(world_pos: Vector2i) -> WorldCell:
	var chunk_sz: int = config.chunk_size if config != null else 16
	var ccoord := ChunkCoord.world_to_chunk(world_pos, chunk_sz)
	var chunk: ChunkData = loaded_chunks.get(ccoord, null)
	if chunk != null:
		return chunk.get_cell(world_pos)
	return null


## Espera a que se completen todas las tareas pendientes del scheduler e integra sus resultados.
## Utilizado para inicializaciones garantizadas o pruebas de convergencia.
func flush_pending(timeout_ms: int = 10000) -> void:
	var start_time := Time.get_ticks_msec()
	while not chunk_states.is_empty():
		var all_loaded := true
		for c in chunk_states:
			if chunk_states[c] != ChunkState.LOADED:
				all_loaded = false
				break
		if all_loaded:
			break

		poll_completed()
		if Time.get_ticks_msec() - start_time > timeout_ms:
			push_warning("flush_pending timeout exceeded")
			break
		OS.delay_msec(1)

	poll_completed()


func shutdown() -> void:
	if scheduler != null:
		scheduler.shutdown()


## Asocia perezosamente los POIs que intersectan el área del chunk sin generar mazmorras
func _attach_pois_to_chunk(chunk_data: ChunkData) -> void:
	if chunk_data == null or poi_generator == null:
		return
	
	var m_sz: int = poi_generator.macro_cell_size if "macro_cell_size" in poi_generator else 256
	var min_mx: int = int(floor(float(chunk_data.core_bounds.position.x) / float(m_sz)))
	var max_mx: int = int(floor(float(chunk_data.core_bounds.end.x - 1) / float(m_sz)))
	var min_my: int = int(floor(float(chunk_data.core_bounds.position.y) / float(m_sz)))
	var max_my: int = int(floor(float(chunk_data.core_bounds.end.y - 1) / float(m_sz)))

	for my in range(min_my, max_my + 1):
		for mx in range(min_mx, max_mx + 1):
			var m_coord := Vector2i(mx, my)
			if not _evaluated_pois.has(m_coord):
				# Evaluación perezosa del POI de la celda
				var poi = poi_generator.evaluate_and_create_poi(seed_val, m_coord, self)
				_evaluated_pois[m_coord] = poi
			
			var candidate_poi = _evaluated_pois[m_coord]
			if candidate_poi != null and "bounding_rect" in candidate_poi:
				if chunk_data.core_bounds.intersects(candidate_poi.bounding_rect):
					if not (candidate_poi in chunk_data.pois):
						chunk_data.pois.append(candidate_poi)
