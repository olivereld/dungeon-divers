class_name WorldNavigationGrid
extends RefCounted

## Registro global y autoridad de consulta de navegación basada en chunks.
## Almacena WorldNavigationChunk inmutables indexados por coordenada de chunk.
## No contiene reglas de movimiento ni perfiles de entidades (eso pertenece a MovementRules).

const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")

enum Availability {
	READY,
	UNAVAILABLE
}

signal chunk_registered(coord: Vector2i)
signal chunk_unregistered(coord: Vector2i)

var cell_size: float = 1.0
var chunk_size: int = 16
var world_origin: Vector3 = Vector3.ZERO

# Vector2i (chunk_coord) -> WorldNavigationChunk
var _chunks: Dictionary = {}

func _init(p_cell_size: float = 1.0, p_chunk_size: int = 16, p_origin: Vector3 = Vector3.ZERO) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	chunk_size = maxi(p_chunk_size, 1)
	world_origin = p_origin

func register_chunk(chunk: WorldNavigationChunk) -> void:
	if chunk == null:
		return
	_chunks[chunk.chunk_coord] = chunk
	chunk_registered.emit(chunk.chunk_coord)

func unregister_chunk(coord: Vector2i) -> void:
	if _chunks.erase(coord):
		chunk_unregistered.emit(coord)

func has_chunk(coord: Vector2i) -> bool:
	return _chunks.has(coord)

func _get_chunk_for_cell(cell: Vector2i) -> WorldNavigationChunk:
	var ccoord := _ChunkCoordScript.world_to_chunk(cell, chunk_size)
	return _chunks.get(ccoord, null)

func has_cell(cell: Vector2i) -> bool:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return false
	return chunk.has_cell(cell)

func get_cell_availability(cell: Vector2i) -> int:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null or not chunk.has_cell(cell):
		return Availability.UNAVAILABLE
	return Availability.READY

func get_cell(cell: Vector2i) -> WorldNavigationCell:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return null
	return chunk.get_cell(cell)

func is_walkable(cell: Vector2i) -> bool:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return false
	return chunk.is_walkable(cell)

func get_height(cell: Vector2i) -> float:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return 0.0
	return chunk.get_height(cell)

func get_elevation_level(cell: Vector2i) -> int:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return 0
	return chunk.get_elevation_level(cell)

## Primitiva de soporte inferior para evaluar caídas:
## Comprueba si en la celda 'cell' existe superficie transitable dentro de un desnivel de hasta max_depth.
func find_lower_support(cell: Vector2i, max_depth: int = 6) -> Dictionary:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null or not chunk.has_cell(cell):
		return {"found": false, "elevation_level": 0, "height": 0.0, "walkable": false}

	var elevation := chunk.get_elevation_level(cell)
	var height_val := chunk.get_height(cell)
	var walkable_val := chunk.is_walkable(cell)

	return {
		"found": true,
		"elevation_level": elevation,
		"height": height_val,
		"walkable": walkable_val
	}

# --- Conversiones Espaciales (Cell <-> World) ---

func cell_to_world(cell: Vector2i, y_offset: float = 0.0) -> Vector3:
	var h: float = get_height(cell)
	var wx: float = (float(cell.x) + 0.5) * cell_size + world_origin.x
	var wz: float = (float(cell.y) + 0.5) * cell_size + world_origin.z
	var wy: float = h + world_origin.y + y_offset
	return Vector3(wx, wy, wz)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_x: float = (world_pos.x - world_origin.x) / cell_size
	var local_z: float = (world_pos.z - world_origin.z) / cell_size
	return Vector2i(int(floor(local_x)), int(floor(local_z)))
