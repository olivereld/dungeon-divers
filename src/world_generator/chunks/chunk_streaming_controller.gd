class_name ChunkStreamingController
extends RefCounted

## Controlador desacoplado que evalúa la posición y cinemática del jugador para
## determinar de forma predictiva los conjuntos de chunks (VISIBLE, PRELOAD, CACHE)
## y calcular sus prioridades relativas.
## 0 generación directa de chunks ni dependencias de nodos 3D de escena.

const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")

var config: ChunkConfig = null

## Último estado calculado
var current_chunk: Vector2i = Vector2i.ZERO
var predicted_chunk: Vector2i = Vector2i.ZERO
var movement_direction: Vector2 = Vector2.ZERO

var visible_chunks: Array[Vector2i] = []
var preload_chunks: Array[Vector2i] = []
var cache_chunks: Array[Vector2i] = []

## Prioridades escalares calculadas por coordenada (Vector2i -> float)
var chunk_priorities: Dictionary = {}

func _init(p_config: ChunkConfig = null) -> void:
	config = p_config if p_config != null else ChunkConfig.new()

## Procesa la posición y velocidad en el espacio continuo del mundo
## Retorna un diccionario con las colecciones calculadas y prioridades.
func update_target(
	world_pos: Vector3,
	velocity: Vector3,
	cell_size: float = 1.0
) -> Dictionary:
	var chunk_sz: int = config.chunk_size if config != null else 16
	var cell_x := floori(world_pos.x / cell_size)
	var cell_z := floori(world_pos.z / cell_size)
	var new_current := _ChunkCoordScript.world_to_chunk(Vector2i(cell_x, cell_z), chunk_sz)

	# Dirección horizontal normalizada en X-Z
	var vel_2d := Vector2(velocity.x, velocity.z)
	var is_moving := vel_2d.length_squared() > 0.05
	movement_direction = vel_2d.normalized() if is_moving else Vector2.ZERO

	# Proyección cinemática de chunks hacia adelante
	var pred_dist: float = config.prediction_distance_chunks if config != null else 2.0
	var offset_chunks := Vector2i(roundi(movement_direction.x * pred_dist), roundi(movement_direction.y * pred_dist))
	predicted_chunk = new_current + offset_chunks

	current_chunk = new_current

	# Recalcular conjuntos de los tres radios
	var vis_r: int = config.visible_radius if config != null else 2
	var pre_r: int = config.preload_radius if config != null else 5
	var cac_r: int = config.cache_radius if config != null else 8

	visible_chunks = _get_chunks_in_radius(current_chunk, vis_r, true)
	preload_chunks = _get_chunks_in_radius(current_chunk, pre_r, true)
	cache_chunks = _get_chunks_in_radius(current_chunk, cac_r, false)

	# Calcular prioridades escalares (Mayor número = mayor urgencia de procesamiento)
	chunk_priorities.clear()
	var visible_lookup: Dictionary = {}
	for c in visible_chunks:
		visible_lookup[c] = true

	for c in preload_chunks:
		var priority: float = _compute_chunk_priority(c, current_chunk, predicted_chunk, movement_direction, visible_lookup.has(c))
		chunk_priorities[c] = priority

	return {
		"current_chunk": current_chunk,
		"predicted_chunk": predicted_chunk,
		"visible_chunks": visible_chunks,
		"preload_chunks": preload_chunks,
		"cache_chunks": cache_chunks,
		"priorities": chunk_priorities
	}

## Retorna true si una coordenada cae dentro del radio de caché permitido
func is_in_cache_range(coord: Vector2i, center: Vector2i = Vector2i.MAX) -> bool:
	var c := current_chunk if center == Vector2i.MAX else center
	var cac_r: int = config.cache_radius if config != null else 8
	var unload_m: float = config.unload_margin if config != null else 0.65
	var max_r := float(cac_r) + unload_m
	var dx := float(coord.x - c.x)
	var dy := float(coord.y - c.y)
	return (dx * dx + dy * dy) <= (max_r * max_r)

## Calcula la prioridad de un chunk combinando cercanía, alineación con vector de avance y visibilidad
func _compute_chunk_priority(
	coord: Vector2i,
	center: Vector2i,
	pred_center: Vector2i,
	dir: Vector2,
	is_visible: bool
) -> float:
	var dist_center := Vector2(coord - center).length()
	var dist_pred := Vector2(coord - pred_center).length()

	# Base: 1000 si está en el radio visible, 500 si es preload
	var base_score: float = 1000.0 if is_visible else 500.0

	# Penalización por distancia
	var dist_penalty: float = dist_center * 25.0

	# Bonificación por dirección de avance del jugador
	var direction_bonus: float = 0.0
	if dir != Vector2.ZERO:
		var to_chunk := Vector2(coord - center).normalized()
		var alignment := dir.dot(to_chunk) # -1.0 a +1.0
		if alignment > 0.0:
			direction_bonus = alignment * 60.0
		# Prioridad especial si está cerca del chunk predicho
		if dist_pred < 1.5:
			direction_bonus += 80.0

	return maxf(1.0, base_score - dist_penalty + direction_bonus)

func _get_chunks_in_radius(center: Vector2i, radius: int, circular: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var r_sq := float(radius) * float(radius) + 0.1
	for cy in range(center.y - radius, center.y + radius + 1):
		for cx in range(center.x - radius, center.x + radius + 1):
			if circular:
				var dx := float(cx - center.x)
				var dy := float(cy - center.y)
				if (dx * dx + dy * dy) > r_sq:
					continue
			result.append(Vector2i(cx, cy))
	return result
