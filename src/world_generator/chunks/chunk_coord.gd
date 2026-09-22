class_name ChunkCoord
extends RefCounted

## Utilidades de conversión y límites entre coordenadas de mundo y de chunks.

## Convierte una coordenada de celda mundial (x, y) a la coordenada de chunk (cx, cy).
## Utiliza floori para soportar correctamente coordenadas mundiales negativas.
static func world_to_chunk(world_pos: Vector2i, chunk_size: int) -> Vector2i:
	return Vector2i(
		floori(float(world_pos.x) / float(chunk_size)),
		floori(float(world_pos.y) / float(chunk_size))
	)

## Retorna la coordenada de celda mundial del origen (esquina superior izquierda) del chunk.
static func chunk_to_world_origin(chunk_coord: Vector2i, chunk_size: int) -> Vector2i:
	return chunk_coord * chunk_size

## Retorna los límites rectangulares netos del chunk en coordenadas de celda (sin halo).
static func get_core_bounds(chunk_coord: Vector2i, chunk_size: int) -> Rect2i:
	return Rect2i(chunk_coord * chunk_size, Vector2i(chunk_size, chunk_size))

## Retorna los límites ampliados con margen de generación (halo).
static func get_generation_bounds(chunk_coord: Vector2i, chunk_size: int, margin: int) -> Rect2i:
	var origin := chunk_coord * chunk_size
	return Rect2i(
		origin - Vector2i(margin, margin),
		Vector2i(chunk_size + margin * 2, chunk_size + margin * 2)
	)
