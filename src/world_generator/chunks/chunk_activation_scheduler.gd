class_name ChunkActivationScheduler
extends RefCounted

## Planificador de activación incremental en Main Thread con presupuesto estricto por frame.
## Desacopla la recepción de ChunkData (READY) de la materialización en el árbol de escena (ChunkView).
## Divide la activación de cada chunk en micro-etapas:
## 1. TERRAIN_MESH
## 2. COLLISION (Máximo 1 operación pesada de create_trimesh_shape por frame)
## 3. WATER
## 4. POI (Gameplay-critical)
## 5. VEGETATION (Decorativo)
## 6. VISIBLE (Agregado al SceneTree)
##
## Comprueba el presupuesto de tiempo (budget_ms) ENTRE ETAPAS, pausando el trabajo si se agota
## para continuar en el siguiente frame sin provocar caídas bruscas de FPS.

signal chunk_activated(coord: Vector2i, chunk_view: Node3D)

const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _DungeonEntrancePOIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")

enum Stage {
	TERRAIN_MESH = 1,
	COLLISION = 2,
	WATER = 3,
	POI = 4,
	VEGETATION = 5,
	COMPLETE = 6
}

class ActivationTask extends RefCounted:
	var coord: Vector2i
	var chunk_data: ChunkData
	var priority: float
	var token: int
	var stage: int = Stage.TERRAIN_MESH

	var chunk_view: Node3D = null
	var terrain_mesh: ArrayMesh = null

	# Telemetría granular por etapa (msec)
	var time_terrain_ms: float = 0.0
	var time_collision_ms: float = 0.0
	var time_water_ms: float = 0.0
	var time_poi_ms: float = 0.0
	var time_vegetation_ms: float = 0.0

	func _init(p_coord: Vector2i, p_data: ChunkData, p_priority: float = 0.0, p_token: int = 0) -> void:
		coord = p_coord
		chunk_data = p_data
		priority = p_priority
		token = p_token


var _queue: Array = [] # Array[ActivationTask]
var _active_tokens: Dictionary = {}

# Estadísticas y Telemetría pública
var total_activated: int = 0
var last_frame_activation_time_ms: float = 0.0
var telemetry_terrain_ms: float = 0.0
var telemetry_collision_ms: float = 0.0
var telemetry_water_ms: float = 0.0
var telemetry_vegetation_ms: float = 0.0
var telemetry_total_activation_ms: float = 0.0


## Encola un chunk listo para ser activado con prioridad
func enqueue_chunk(coord: Vector2i, chunk_data: ChunkData, priority: float = 0.0, token: int = 0) -> void:
	_active_tokens[coord] = token
	# Deduplicar si ya estaba en cola
	for item in _queue:
		var task := item as ActivationTask
		if task != null and task.coord == coord:
			task.chunk_data = chunk_data
			task.priority = priority
			task.token = token
			return

	_queue.append(ActivationTask.new(coord, chunk_data, priority, token))


## Cancela la activación pendiente o en progreso de una coordenada
func cancel_activation(coord: Vector2i) -> void:
	_active_tokens.erase(coord)
	for i in range(_queue.size() - 1, -1, -1):
		var task := _queue[i] as ActivationTask
		if task != null and task.coord == coord:
			if task.chunk_view != null and not task.chunk_view.is_inside_tree():
				task.chunk_view.queue_free()
			_queue.remove_at(i)


## Invalida todas las activaciones pendientes
func clear() -> void:
	for item in _queue:
		var task := item as ActivationTask
		if task != null and task.chunk_view != null and not task.chunk_view.is_inside_tree():
			task.chunk_view.queue_free()
	_queue.clear()
	_active_tokens.clear()


func get_queue_size() -> int:
	return _queue.size()


## Procesa activaciones pendientes de forma incremental verificando presupuesto entre etapas.
## Garantiza que create_trimesh_shape() solo ocurra como máximo 1 vez por frame.
func process_activations(
	budget_ms: float,
	max_activations: int,
	profile: WorldProfile,
	water_visible: bool,
	parent_container: Node3D,
	dungeon_callback: Callable,
	vegetation_callback: Callable
) -> Array[Vector2i]:
	if _queue.is_empty():
		last_frame_activation_time_ms = 0.0
		return []

	var t_start := Time.get_ticks_usec()
	var activated_coords: Array[Vector2i] = []
	var collisions_done_this_frame := 0
	var completed_chunks_count := 0

	var cell_size: float = profile.cell_size if profile != null else 1.0

	while not _queue.is_empty() and completed_chunks_count < max_activations:
		var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
		# Si ya se agotó el presupuesto y se ha avanzado algo, pausar hasta el próximo frame
		if elapsed_ms >= budget_ms and (completed_chunks_count > 0 or collisions_done_this_frame > 0):
			break

		# Seleccionar tarea con mayor prioridad
		var best_idx := 0
		var best_p := -999999.0
		for i in range(_queue.size()):
			var candidate := _queue[i] as ActivationTask
			if candidate != null and candidate.priority > best_p:
				best_p = candidate.priority
				best_idx = i

		var current_task: ActivationTask = _queue[best_idx] as ActivationTask
		if current_task == null:
			_queue.remove_at(best_idx)
			continue

		# Validar token
		var expected_tok: int = _active_tokens.get(current_task.coord, -1)
		if current_task.token != expected_tok and expected_tok != -1:
			if current_task.chunk_view != null:
				current_task.chunk_view.queue_free()
			_queue.remove_at(best_idx)
			continue

		# Inicializar ChunkView base si no existe aún
		if current_task.chunk_view == null:
			var origin: Vector2i = current_task.chunk_data.core_bounds.position
			current_task.chunk_view = Node3D.new()
			current_task.chunk_view.name = "Chunk_%d_%d" % [current_task.coord.x, current_task.coord.y]
			current_task.chunk_view.position = Vector3(float(origin.x) * cell_size, 0.0, float(origin.y) * cell_size)

		# MÁQUINA DE ESTADOS INCREMENTAL POR ETAPAS
		var task_finished := false

		while current_task.stage < Stage.COMPLETE:
			var stage_start := Time.get_ticks_usec()

			match current_task.stage:
				Stage.TERRAIN_MESH:
					# Etapa 1: Malla visual de terreno
					current_task.terrain_mesh = TerrainMeshBuilder.build_mesh(current_task.chunk_data, cell_size, profile)
					var terrain_mi := MeshInstance3D.new()
					terrain_mi.name = "TerrainMesh"
					terrain_mi.mesh = current_task.terrain_mesh
					terrain_mi.set_surface_override_material(0, _TerrainMaterialScript.create_material(profile))
					current_task.chunk_view.add_child(terrain_mi)

					current_task.time_terrain_ms += float(Time.get_ticks_usec() - stage_start) / 1000.0
					current_task.stage = Stage.COLLISION

				Stage.COLLISION:
					# Si ya hicimos una colisión pesada en este frame en OTRA tarea previa, pausar antes de empezar la colisión
					if collisions_done_this_frame >= 1 and completed_chunks_count > 0:
						# Salir del while interno sin avanzar de etapa
						break

					# Etapa 2: Malla física de colisión
					if current_task.terrain_mesh != null:
						var static_body := StaticBody3D.new()
						static_body.name = "TerrainCollision"
						var col_shape := CollisionShape3D.new()
						col_shape.name = "CollisionShape3D"
						col_shape.shape = current_task.terrain_mesh.create_trimesh_shape()
						static_body.add_child(col_shape)
						current_task.chunk_view.add_child(static_body)

					collisions_done_this_frame += 1
					current_task.time_collision_ms += float(Time.get_ticks_usec() - stage_start) / 1000.0
					current_task.stage = Stage.WATER

				Stage.WATER:
					# Etapa 3: Agua
					if current_task.chunk_data.hydrology != null:
						var water_node: Node3D = _WaterRendererScript.build_water_node(current_task.chunk_data, profile)
						if water_node != null:
							water_node.visible = water_visible
							current_task.chunk_view.add_child(water_node)

					current_task.time_water_ms += float(Time.get_ticks_usec() - stage_start) / 1000.0
					current_task.stage = Stage.POI

				Stage.POI:
					# Etapa 4: POIs (Gameplay)
					if "pois" in current_task.chunk_data and current_task.chunk_data.pois != null:
						for poi in current_task.chunk_data.pois:
							if poi != null and "world_position" in poi:
								var cell_x := int(floor(poi.world_position.x))
								var cell_z := int(floor(poi.world_position.z))
								if not current_task.chunk_data.core_bounds.has_point(Vector2i(cell_x, cell_z)):
									continue

								var entrance_node: Node3D = _DungeonEntrancePOIViewScript.new(poi)
								var cell_h: float = poi.world_position.y
								if current_task.chunk_data.has_method("get_cell_or_seam"):
									var c = current_task.chunk_data.get_cell_or_seam(Vector2i(cell_x, cell_z))
									if c != null:
										cell_h = c.height
								elif current_task.chunk_data.has_cell(Vector2i(cell_x, cell_z)):
									var c = current_task.chunk_data.get_cell(Vector2i(cell_x, cell_z))
									if c != null:
										cell_h = c.height

								var world_pos_3d := Vector3(float(cell_x) * cell_size + cell_size * 0.5, cell_h, float(cell_z) * cell_size + cell_size * 0.5)
								var rel_pos = world_pos_3d - current_task.chunk_view.position
								entrance_node.position = rel_pos
								if "orientation_deg" in poi:
									entrance_node.rotation_degrees.y = poi.orientation_deg

								if dungeon_callback.is_valid():
									entrance_node.dungeon_enter_requested.connect(dungeon_callback)

								current_task.chunk_view.add_child(entrance_node)

					current_task.time_poi_ms += float(Time.get_ticks_usec() - stage_start) / 1000.0
					current_task.stage = Stage.VEGETATION

				Stage.VEGETATION:
					# Etapa 5: Vegetación decorativa
					if vegetation_callback.is_valid():
						vegetation_callback.call(current_task.chunk_view, current_task.chunk_data, current_task.chunk_data.core_bounds.position, cell_size)

					current_task.time_vegetation_ms += float(Time.get_ticks_usec() - stage_start) / 1000.0
					current_task.stage = Stage.COMPLETE
					task_finished = true

			# Comprobar presupuesto entre etapas si la tarea aún no se ha completado
			var current_elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
			if current_task.stage < Stage.COMPLETE and current_elapsed_ms >= budget_ms:
				# Si el presupuesto se agotó a mitad de etapas, nos detenemos aquí y continuaremos en el siguiente frame
				break

		# Si el chunk completó todas las etapas, adjuntarlo y emitir señal
		if current_task.stage == Stage.COMPLETE:
			_queue.remove_at(best_idx)
			if parent_container != null:
				parent_container.add_child(current_task.chunk_view)

			# Actualizar métricas acumuladas
			telemetry_terrain_ms = current_task.time_terrain_ms
			telemetry_collision_ms = current_task.time_collision_ms
			telemetry_water_ms = current_task.time_water_ms
			telemetry_vegetation_ms = current_task.time_vegetation_ms

			chunk_activated.emit(current_task.coord, current_task.chunk_view)
			activated_coords.append(current_task.coord)
			completed_chunks_count += 1
			total_activated += 1
		else:
			# El chunk no terminó sus etapas en este frame; salimos del bucle para no sobrepasar el presupuesto
			break

	var total_frame_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
	last_frame_activation_time_ms = total_frame_ms
	telemetry_total_activation_ms = total_frame_ms
	return activated_coords
