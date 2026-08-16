class_name ChunkManager
extends Node3D

## Gestor de partición de mazmorra en Chunks para optimización y escalabilidad.

@export var chunk_size: int = 16

var _grid_width: int = 0
var _grid_height: int = 0
var _chunks: Dictionary = {} # Vector2i chunk_coord -> Rect2i

func initialize(grid: CellGrid) -> void:
	_grid_width = grid.width
	_grid_height = grid.height
	_chunks.clear()

	var chunks_x: int = ceili(float(_grid_width) / float(chunk_size))
	var chunks_y: int = ceili(float(_grid_height) / float(chunk_size))

	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var rect := Rect2i(
				cx * chunk_size,
				cy * chunk_size,
				mini(chunk_size, _grid_width - cx * chunk_size),
				mini(chunk_size, _grid_height - cy * chunk_size)
			)
			_chunks[Vector2i(cx, cy)] = rect

func get_chunk_count() -> int:
	return _chunks.size()

func get_chunk_bounds(chunk_coord: Vector2i) -> Rect2i:
	return _chunks.get(chunk_coord, Rect2i())

func world_to_chunk_coord(world_cell: Vector2i) -> Vector2i:
	return Vector2i(world_cell.x / chunk_size, world_cell.y / chunk_size)
