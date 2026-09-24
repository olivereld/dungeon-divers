class_name ChunkWorld
extends Node3D

## Autoridad de alto nivel y coordinador runtime del mundo por chunks.
## Orquesta semilla, perfil, configuración, hidrología compartida y el ChunkManager.
signal chunk_loaded(coord: Vector2i, chunk_data: ChunkData)
signal chunk_unloaded(coord: Vector2i)
signal dungeon_enter_requested(poi: RefCounted, dungeon_result: RefCounted, player_node: Node3D)

const _ChunkManagerScript = preload("res://src/world_generator/chunks/chunk_manager.gd")
const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")
const _ProceduralRockGeneratorScript = preload("res://src/world_renderer/procedural_rock_generator.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _DungeonEntrancePOIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")
const _ChunkStreamingControllerScript = preload("res://src/world_generator/chunks/chunk_streaming_controller.gd")
const _ChunkActivationSchedulerScript = preload("res://src/world_generator/chunks/chunk_activation_scheduler.gd")

@export var world_seed: int = 12345
@export var render_distance: int = 2

var profile: WorldProfile = null
var config: ChunkConfig = null
var shared_hydrology: HydrologyResult = null
var chunk_manager: RefCounted = null
var streaming_controller: RefCounted = null
var activation_scheduler: RefCounted = null

## Coordenada del chunk actualmente activo (donde se ubica el jugador / objetivo)
var active_chunk: Vector2i = Vector2i.ZERO

## Objetivo móvil opcional a rastrear (e.g. Player)
var tracked_target: Node3D = null
var _last_tracked_pos: Vector3 = Vector3.ZERO

## Diccionario de vistas 3D de chunks cargados (Vector2i -> Node3D)
var chunk_views: Dictionary = {}

## Historial de tiempos de integración en el Main Thread (BLOQUE 9)
var integration_timings: Array = []

## Contenedor de nodos de chunks en la jerarquía
var chunks_container: Node3D = null

## Visibilidad global de la superficie de agua en los chunks
var water_visible: bool = true

## Helper para generación de mallas de vegetación
var _cached_conifer_mesh: Mesh = null
var _cached_shrub_mesh: Mesh = null
var _cached_rock_mesh: Mesh = null

func set_water_visible(p_visible: bool) -> void:
	water_visible = p_visible
	for cv in chunk_views.values():
		if cv != null and is_instance_valid(cv):
			var w_node = cv.get_node_or_null("WaterRoot")
			if w_node != null:
				w_node.visible = water_visible

func toggle_water_visible() -> bool:
	set_water_visible(not water_visible)
	return water_visible



func _init() -> void:
	pass


## Inicializa el ChunkWorld y su ChunkManager.
func initialize(
	p_seed: int,
	p_profile: WorldProfile = null,
	p_config: ChunkConfig = null,
	p_shared_hydro: HydrologyResult = null,
	p_render_dist: int = -1
) -> void:
	world_seed = p_seed
	profile = p_profile if p_profile != null else TaigaWorldProfile.new()
	config = p_config if p_config != null else ChunkConfig.new()
	config.is_unbounded = true
	if p_render_dist > 0:
		render_distance = p_render_dist
		config.render_distance = p_render_dist
	elif config.render_distance > 0:
		render_distance = config.render_distance
	shared_hydrology = p_shared_hydro

	if chunks_container == null:
		chunks_container = Node3D.new()
		chunks_container.name = "ChunksContainer"
		add_child(chunks_container)

	chunk_manager = _ChunkManagerScript.new(
		world_seed,
		profile,
		config,
		shared_hydrology
	)

	streaming_controller = _ChunkStreamingControllerScript.new(config)
	activation_scheduler = _ChunkActivationSchedulerScript.new()
	activation_scheduler.chunk_activated.connect(_on_chunk_activated)

	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)


## Carga explícitamente un área inicial alrededor de una coordenada central.
## Si radius < 0, utiliza render_distance de forma síncrona/garantizada.
func load_initial_area(center_coord: Vector2i = Vector2i.ZERO, radius: int = -1) -> void:
	bootstrap_minimum_area(center_coord, radius)


## Bootstrap inicial optimizado: activa de inmediato solo el área mínima jugable (radio 1)
## para que el jugador pueda interactuar al instante, dejando los radios mayores para background streaming.
func bootstrap_minimum_area(center_coord: Vector2i = Vector2i.ZERO, full_radius: int = -1) -> void:
	var r := render_distance if full_radius < 0 else full_radius
	active_chunk = center_coord

	if chunk_manager != null:
		# 1. Encolar el área requerida completa en el scheduler asíncrono
		chunk_manager.update_streaming(center_coord, r)

		# 2. Generar y activar de forma inmediata únicamente el núcleo jugable (radio 1)
		var core_coords: Array[Vector2i] = []
		for cy in range(center_coord.y - 1, center_coord.y + 2):
			for cx in range(center_coord.x - 1, center_coord.x + 2):
				core_coords.append(Vector2i(cx, cy))

		for c in core_coords:
			if not chunk_manager.has_chunk(c):
				chunk_manager.load_chunk(c)

		# Procesar inmediatamente las activaciones del área núcleo
		if activation_scheduler != null:
			activation_scheduler.process_activations(
				100.0,
				core_coords.size() + 2,
				profile,
				water_visible,
				chunks_container if chunks_container != null else self,
				Callable(self, "_on_dungeon_enter_forward"),
				Callable(self, "_spawn_chunk_vegetation")
			)



## Espera y procesa todas las peticiones asíncronas pendientes del scheduler.
func flush_async_queue(timeout_ms: int = 10000) -> void:
	if chunk_manager != null and chunk_manager.has_method("flush_pending"):
		chunk_manager.flush_pending(timeout_ms)


## Asigna el nodo del jugador u objetivo a rastrear.
func set_tracked_target(target: Node3D) -> void:
	tracked_target = target
	if tracked_target != null:
		_last_tracked_pos = tracked_target.global_position if tracked_target.is_inside_tree() else tracked_target.position
		update_player_streaming()


func set_active_target(target: Node3D) -> void:
	set_tracked_target(target)


## Actualiza el streaming evaluando la posición y velocidad cinemática del jugador.
func update_player_streaming() -> void:
	if tracked_target == null or not is_instance_valid(tracked_target):
		return
	var target_pos: Vector3 = tracked_target.global_position if tracked_target.is_inside_tree() else tracked_target.position
	var velocity := Vector3.ZERO
	if "velocity" in tracked_target:
		velocity = tracked_target.velocity
	else:
		velocity = target_pos - _last_tracked_pos
	_last_tracked_pos = target_pos

	var cell_size: float = profile.cell_size if profile != null else 1.0
	var streaming_data: Dictionary = {}
	if streaming_controller != null:
		streaming_data = streaming_controller.update_target(target_pos, velocity, cell_size)
		active_chunk = streaming_data.get("current_chunk", active_chunk)
	else:
		var world_x := floori(target_pos.x / cell_size)
		var world_y := floori(target_pos.z / cell_size)
		var chunk_sz: int = config.chunk_size if config != null else 16
		active_chunk = ChunkCoord.world_to_chunk(Vector2i(world_x, world_y), chunk_sz)

	if chunk_manager != null:
		var priorities: Dictionary = streaming_data.get("priorities", {})
		chunk_manager.update_streaming(active_chunk, render_distance, priorities)


## Ajusta dinámicamente el radio de chunks cargados en tiempo de ejecución.
func set_render_distance(p_dist: int) -> void:
	render_distance = clampi(p_dist, 1, 8)
	if config != null:
		config.render_distance = render_distance
	if chunk_manager != null:
		chunk_manager.update_streaming(active_chunk, render_distance)


func _physics_process(_delta: float) -> void:
	poll_async_generation()
	if tracked_target != null:
		update_player_streaming()


func _process(_delta: float) -> void:
	poll_async_generation()


## Extrae resultados de generación y procesa la activación bajo presupuesto por frame.
func poll_async_generation() -> Array[Vector2i]:
	var integrated: Array[Vector2i] = []
	if chunk_manager != null and chunk_manager.has_method("poll_completed"):
		integrated = chunk_manager.poll_completed()

	if activation_scheduler != null:
		var budget: float = config.activation_budget_ms if config != null else 2.0
		var max_acts: int = config.max_chunk_activations_per_frame if config != null else 1
		activation_scheduler.process_activations(
			budget,
			max_acts,
			profile,
			water_visible,
			chunks_container if chunks_container != null else self,
			Callable(self, "_on_dungeon_enter_forward"),
			Callable(self, "_spawn_chunk_vegetation")
		)

	return integrated



func shutdown() -> void:
	if chunk_manager != null and chunk_manager.has_method("shutdown"):
		chunk_manager.shutdown()


func _exit_tree() -> void:
	shutdown()


## Actualiza active_chunk a partir de una posición 3D en el mundo.
func update_active_chunk_from_position(world_pos_3d: Vector3) -> Vector2i:
	var cell_size: float = profile.cell_size if profile != null else 1.0
	var world_x := floori(world_pos_3d.x / cell_size)
	var world_y := floori(world_pos_3d.z / cell_size)
	var chunk_sz: int = config.chunk_size if config != null else 16
	active_chunk = ChunkCoord.world_to_chunk(Vector2i(world_x, world_y), chunk_sz)
	return active_chunk


## Consulta una WorldCell a partir de coordenadas discretas de celda (x, y).
func get_cell_at_world_pos(world_pos: Vector2i) -> WorldCell:
	if chunk_manager != null:
		return chunk_manager.get_cell(world_pos)
	return null


## Consulta una WorldCell a partir de una posición continua en el espacio 3D (X, Z).
func get_cell_at_position_3d(pos_3d: Vector3) -> WorldCell:
	var cell_size: float = profile.cell_size if profile != null else 1.0
	var world_pos := Vector2i(
		floori(pos_3d.x / cell_size),
		floori(pos_3d.z / cell_size)
	)
	return get_cell_at_world_pos(world_pos)


## Obtiene el ChunkData de una coordenada si está cargado.
func get_chunk(coord: Vector2i) -> ChunkData:
	if chunk_manager != null:
		return chunk_manager.get_chunk(coord)
	return null


## Retorna las coordenadas de todos los chunks actualmente en memoria.
func get_loaded_chunk_coords() -> Array[Vector2i]:
	if chunk_manager != null:
		return chunk_manager.get_loaded_coords()
	return []


## Callback invocado por ChunkManager cuando un chunk se genera y almacena en memoria.
func _on_chunk_loaded(coord: Vector2i, chunk_data: ChunkData) -> void:
	if chunk_views.has(coord):
		return

	if activation_scheduler != null:
		var priority: float = 0.0
		if streaming_controller != null:
			priority = streaming_controller.chunk_priorities.get(coord, 100.0)
		activation_scheduler.enqueue_chunk(coord, chunk_data, priority)
	else:
		# Fallback síncrono directo si no hay activation_scheduler
		_build_chunk_view_direct(coord, chunk_data)


func _on_chunk_activated(coord: Vector2i, chunk_view: Node3D) -> void:
	chunk_views[coord] = chunk_view
	chunk_loaded.emit(coord, get_chunk(coord))


## Callback invocado por ChunkManager cuando un chunk se descarga de memoria.
func _on_chunk_unloaded(coord: Vector2i) -> void:
	if activation_scheduler != null:
		activation_scheduler.cancel_activation(coord)

	var chunk_view: Node3D = chunk_views.get(coord, null)
	if chunk_view != null:
		chunk_views.erase(coord)
		chunk_view.queue_free()
		chunk_unloaded.emit(coord)


func _on_dungeon_enter_forward(poi: RefCounted, d_res: RefCounted, p_node: Node3D) -> void:
	dungeon_enter_requested.emit(poi, d_res, p_node)


func _build_chunk_view_direct(coord: Vector2i, chunk_data: ChunkData) -> void:
	var scheduler_helper := _ChunkActivationSchedulerScript.new()
	var chunk_view: Node3D = scheduler_helper._build_chunk_view(
		coord,
		chunk_data,
		profile,
		water_visible,
		Callable(self, "_on_dungeon_enter_forward"),
		Callable(self, "_spawn_chunk_vegetation")
	)
	if chunk_view != null:
		if chunks_container != null:
			chunks_container.add_child(chunk_view)
		else:
			add_child(chunk_view)
		chunk_views[coord] = chunk_view



## Instancia la vegetación del chunk posicionada relativamente a su ChunkView
## reutilizando exactamente el pipeline de WorldRenderer (Pino GLB + shader + ProceduralRockGenerator).
func _spawn_chunk_vegetation(
	chunk_view: Node3D,
	chunk_data: ChunkData,
	origin: Vector2i,
	cell_size: float
) -> void:
	if chunk_data.vegetation.is_empty():
		return

	var origin_3d := Vector3(float(origin.x) * cell_size, 0.0, float(origin.y) * cell_size)
	WorldRenderer.spawn_vegetation(chunk_view, chunk_data.vegetation, origin_3d, profile)


## Crea y configura un IsometricCameraRig programado para enfocar un objetivo o el centro activo.
func setup_isometric_camera(p_target: Node3D = null) -> IsometricCameraRig:
	var rig = _IsometricCameraRigScript.new()
	rig.name = "IsometricCameraRig"
	rig.yaw_degrees = 45.0
	rig.pitch_degrees = 35.264
	rig.zoom_min = 6.0
	rig.zoom_max = 120.0
	rig.default_zoom = 22.0
	rig.zoom_step = 4.0
	rig.zoom_smoothing = 14.0
	rig.follow_speed = 12.0
	add_child(rig)

	if p_target != null:
		rig.set_target(p_target)
		rig.set_follow_enabled(true)
		rig.teleport_to_target()
	return rig
