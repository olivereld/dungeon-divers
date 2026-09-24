class_name ChunkActivationScheduler
extends RefCounted

## Planificador de activación en Main Thread con límite de tiempo por frame (Frame Budget).
## Desacopla la recepción de ChunkData (READY) de la materialización en el árbol de escena (ChunkView).
## Construye cada chunk en etapas ordenadas y priorizadas:
## 1. TerrainMesh
## 2. TerrainCollision
## 3. Water
## 4. POI (Gameplay-critical)
## 5. Vegetation (Decorativo)

signal chunk_activated(coord: Vector2i, chunk_view: Node3D)

const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _DungeonEntrancePOIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")

class ActivationItem:
	var coord: Vector2i
	var chunk_data: ChunkData
	var priority: float
	var token: int

	func _init(p_coord: Vector2i, p_data: ChunkData, p_priority: float = 0.0, p_token: int = 0) -> void:
		coord = p_coord
		chunk_data = p_data
		priority = p_priority
		token = p_token

var _queue: Array = [] # Array[ActivationItem]
var _active_tokens: Dictionary = {}

# Estadísticas de activación
var total_activated: int = 0
var last_frame_activation_time_ms: float = 0.0

## Encola un chunk listo para ser activado con prioridad
func enqueue_chunk(coord: Vector2i, chunk_data: ChunkData, priority: float = 0.0, token: int = 0) -> void:
	_active_tokens[coord] = token
	# Deduplicar si ya estaba en cola
	for item in _queue:
		if item.coord == coord:
			item.chunk_data = chunk_data
			item.priority = priority
			item.token = token
			return

	_queue.append(ActivationItem.new(coord, chunk_data, priority, token))

## Cancela la activación pendiente de una coordenada
func cancel_activation(coord: Vector2i) -> void:
	_active_tokens.erase(coord)
	for i in range(_queue.size() - 1, -1, -1):
		if _queue[i].coord == coord:
			_queue.remove_at(i)

## Invalida todas las activaciones pendientes
func clear() -> void:
	_queue.clear()
	_active_tokens.clear()

func get_queue_size() -> int:
	return _queue.size()

## Procesa activaciones pendientes dentro del presupuesto asignado para el frame actual
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

	var activations_count := 0
	while not _queue.is_empty() and activations_count < max_activations:
		var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
		if elapsed_ms >= budget_ms and activations_count > 0:
			break

		# Extraer item con mayor prioridad
		var best_idx := 0
		var best_p := -999999.0
		for i in range(_queue.size()):
			if _queue[i].priority > best_p:
				best_p = _queue[i].priority
				best_idx = i

		var item: ActivationItem = _queue[best_idx]
		_queue.remove_at(best_idx)

		# Validar token
		var expected_tok: int = _active_tokens.get(item.coord, -1)
		if item.token != expected_tok and expected_tok != -1:
			continue

		var chunk_view := _build_chunk_view(
			item.coord,
			item.chunk_data,
			profile,
			water_visible,
			dungeon_callback,
			vegetation_callback
		)

		if chunk_view != null:
			if parent_container != null:
				parent_container.add_child(chunk_view)
			chunk_activated.emit(item.coord, chunk_view)
			activated_coords.append(item.coord)
			activations_count += 1
			total_activated += 1

	last_frame_activation_time_ms = float(Time.get_ticks_usec() - t_start) / 1000.0
	return activated_coords

## Construye la jerarquía visual y física del chunk respetando el orden estricto de activación
func _build_chunk_view(
	coord: Vector2i,
	chunk_data: ChunkData,
	profile: WorldProfile,
	water_visible: bool,
	dungeon_callback: Callable,
	vegetation_callback: Callable
) -> Node3D:
	if chunk_data == null:
		return null

	var cell_size: float = profile.cell_size if profile != null else 1.0
	var origin: Vector2i = chunk_data.core_bounds.position

	var chunk_view := Node3D.new()
	chunk_view.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_view.position = Vector3(float(origin.x) * cell_size, 0.0, float(origin.y) * cell_size)

	# 1. Terreno 3D (Superficie y visual)
	var terrain_mesh := TerrainMeshBuilder.build_mesh(chunk_data, cell_size, profile)
	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "TerrainMesh"
	terrain_mi.mesh = terrain_mesh
	terrain_mi.set_surface_override_material(0, _TerrainMaterialScript.create_material(profile))
	chunk_view.add_child(terrain_mi)

	# 2. Terreno Colisión (Física indispensable para el jugador)
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	chunk_view.add_child(static_body)

	# 3. Agua unificada
	if chunk_data.hydrology != null:
		var water_node: Node3D = _WaterRendererScript.build_water_node(chunk_data, profile)
		if water_node != null:
			water_node.visible = water_visible
			chunk_view.add_child(water_node)

	# 4. POIs críticos para gameplay (Entradas a Mazmorras)
	if "pois" in chunk_data and chunk_data.pois != null:
		for poi in chunk_data.pois:
			if poi != null and "world_position" in poi:
				var cell_x := int(floor(poi.world_position.x))
				var cell_z := int(floor(poi.world_position.z))
				if not chunk_data.core_bounds.has_point(Vector2i(cell_x, cell_z)):
					continue

				var entrance_node: Node3D = _DungeonEntrancePOIViewScript.new(poi)
				var cell_h: float = poi.world_position.y
				if chunk_data.has_method("get_cell_or_seam"):
					var c = chunk_data.get_cell_or_seam(Vector2i(cell_x, cell_z))
					if c != null:
						cell_h = c.height
				elif chunk_data.has_cell(Vector2i(cell_x, cell_z)):
					var c = chunk_data.get_cell(Vector2i(cell_x, cell_z))
					if c != null:
						cell_h = c.height

				var world_pos_3d := Vector3(float(cell_x) * cell_size + cell_size * 0.5, cell_h, float(cell_z) * cell_size + cell_size * 0.5)
				var rel_pos = world_pos_3d - chunk_view.position
				entrance_node.position = rel_pos
				if "orientation_deg" in poi:
					entrance_node.rotation_degrees.y = poi.orientation_deg

				if dungeon_callback.is_valid():
					entrance_node.dungeon_enter_requested.connect(dungeon_callback)

				chunk_view.add_child(entrance_node)

	# 5. Vegetación (Decoración)
	if vegetation_callback.is_valid():
		vegetation_callback.call(chunk_view, chunk_data, origin, cell_size)

	return chunk_view
