class_name ChunkGenerationScheduler
extends RefCounted

## Planificador asíncrono para generación de ChunkData en hilos secundarios (BLOQUE 8).
## Ejecuta exclusivamente WorldPipeline.generate_chunk() en background (cálculo puro de CPU).
## Provee una cola de resultados completados no bloqueante protegida por Mutex.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

class ChunkRequest:
	var coord: Vector2i
	var seed_val: int
	var profile: WorldProfile
	var config: ChunkConfig
	var shared_hydrology: HydrologyResult
	var token: int
	var priority: float
	var enqueue_time_usec: int

	func _init(
		p_coord: Vector2i,
		p_seed: int,
		p_profile: WorldProfile,
		p_config: ChunkConfig,
		p_hydro: HydrologyResult,
		p_token: int,
		p_priority: float = 0.0,
		p_enqueue_time: int = 0
	) -> void:
		coord = p_coord
		seed_val = p_seed
		profile = p_profile
		config = p_config
		shared_hydrology = p_hydro
		token = p_token
		priority = p_priority
		enqueue_time_usec = p_enqueue_time if p_enqueue_time > 0 else Time.get_ticks_usec()


var _thread: Thread = null
var _mutex: Mutex = null
var _semaphore: Semaphore = null
var _is_running: bool = false

# Cola priorizada de solicitudes pendientes (Array[ChunkRequest])
var _pending_requests: Array = []

# Cola de resultados listos (Array[Dictionary]: { "coord": Vector2i, "chunk_data": ChunkData, "token": int })
var _completed_results: Array = []

# Mapeo de tokens activos por coordenada (Vector2i -> int)
var _active_tokens: Dictionary = {}


func _init() -> void:
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_is_running = true
	_thread = Thread.new()
	_thread.start(_worker_loop)


## Encola la generación de un chunk con su respectivo token y prioridad relativa.
## Si ya existía una petición para esa coordenada, actualiza sus datos y prioridad sin duplicar.
func request_chunk(
	coord: Vector2i,
	seed_val: int,
	profile: WorldProfile,
	config: ChunkConfig,
	shared_hydro: HydrologyResult,
	token: int,
	priority: float = 0.0
) -> void:
	_mutex.lock()
	_active_tokens[coord] = token

	# Deduplicación: Si ya está en la cola, actualizar in-place
	var found := false
	for i in range(_pending_requests.size()):
		var existing: ChunkRequest = _pending_requests[i] as ChunkRequest
		if existing.coord == coord:
			existing.seed_val = seed_val
			existing.profile = profile
			existing.config = config
			existing.shared_hydrology = shared_hydro
			existing.token = token
			existing.priority = priority
			found = true
			break

	if not found:
		var req := ChunkRequest.new(coord, seed_val, profile, config, shared_hydro, token, priority)
		_pending_requests.append(req)
		_semaphore.post()

	_mutex.unlock()


## Actualiza dinámicamente la prioridad de una petición pendiente.
func update_priority(coord: Vector2i, new_priority: float) -> void:
	_mutex.lock()
	for i in range(_pending_requests.size()):
		var req: ChunkRequest = _pending_requests[i] as ChunkRequest
		if req.coord == coord:
			req.priority = new_priority
			break
	_mutex.unlock()


## Cancela explícitamente la generación de un chunk pendiente.
func cancel_chunk(coord: Vector2i) -> void:
	_mutex.lock()
	_active_tokens.erase(coord)
	for i in range(_pending_requests.size() - 1, -1, -1):
		var req: ChunkRequest = _pending_requests[i] as ChunkRequest
		if req.coord == coord:
			_pending_requests.remove_at(i)
	_mutex.unlock()


## Invalida el token para una coordenada específica, descartando su resultado si termina.
func invalidate_token(coord: Vector2i, new_token: int) -> void:
	_mutex.lock()
	_active_tokens[coord] = new_token
	_mutex.unlock()


## Invalida todas las solicitudes pendientes.
func cancel_all() -> void:
	_mutex.lock()
	_pending_requests.clear()
	_active_tokens.clear()
	_mutex.unlock()


## Extrae todos los resultados completados hasta el momento.
## ESTA LLAMADA ES ESTRICTAMENTE NO BLOQUEANTE PARA EL MAIN THREAD.
func poll_completed() -> Array:
	_mutex.lock()
	if _completed_results.is_empty():
		_mutex.unlock()
		return []

	var completed: Array = _completed_results.duplicate()
	_completed_results.clear()
	_mutex.unlock()
	return completed


## Detiene limpiamente el worker thread.
func shutdown() -> void:
	if not _is_running:
		return

	_mutex.lock()
	_is_running = false
	_pending_requests.clear()
	_mutex.unlock()

	_semaphore.post()

	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


func _worker_loop() -> void:
	while true:
		_semaphore.wait()

		_mutex.lock()
		if not _is_running:
			_mutex.unlock()
			break

		if _pending_requests.is_empty():
			_mutex.unlock()
			continue

		# Extraer la solicitud con mayor prioridad (Priority Queue)
		var best_idx := 0
		var best_priority := -999999.0
		for i in range(_pending_requests.size()):
			var candidate: ChunkRequest = _pending_requests[i] as ChunkRequest
			if candidate.priority > best_priority:
				best_priority = candidate.priority
				best_idx = i

		var req: ChunkRequest = _pending_requests[best_idx] as ChunkRequest
		_pending_requests.remove_at(best_idx)

		var current_token: int = _active_tokens.get(req.coord, -1)
		# Si la petición fue cancelada o invalidada antes de empezar, la descartamos
		if req.token != current_token:
			_mutex.unlock()
			continue

		_mutex.unlock()

		var t_start_work := Time.get_ticks_usec()
		var queue_time_ms := float(t_start_work - req.enqueue_time_usec) / 1000.0

		# Ejecutar generación procedural en CPU (fuera de mutex, fuera de main thread)
		var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(
			req.seed_val,
			req.coord,
			req.profile,
			req.config,
			req.shared_hydrology
		)

		var t_end_work := Time.get_ticks_usec()
		var gen_time_ms := float(t_end_work - t_start_work) / 1000.0

		_mutex.lock()
		if _is_running:
			_completed_results.append({
				"coord": req.coord,
				"chunk_data": chunk_data,
				"token": req.token,
				"enqueue_time_usec": req.enqueue_time_usec,
				"queue_time_ms": queue_time_ms,
				"gen_time_ms": gen_time_ms
			})
		_mutex.unlock()

