class_name GridToWorld
extends RefCounted

## Centraliza de forma exclusiva la conversión espacial entre la rejilla 2D y el mundo 3D.
## Contrato: Grid X -> World X, Grid Y -> World Z, Altura/Capa -> World Y.
## 100% puro y determinista.

static func cell_to_world(cell: Vector2i, tile_size: float = 2.0, height: float = 0.0) -> Vector3:
	return Vector3(cell.x * tile_size, height, cell.y * tile_size)

static func world_to_cell(world_pos: Vector3, tile_size: float = 2.0) -> Vector2i:
	if tile_size <= 0.0:
		return Vector2i.ZERO
	return Vector2i(roundi(world_pos.x / tile_size), roundi(world_pos.z / tile_size))

static func get_cell_center_world(cell: Vector2i, tile_size: float = 2.0, height: float = 0.0) -> Vector3:
	var half: float = tile_size * 0.5
	return Vector3(cell.x * tile_size + half, height, cell.y * tile_size + half)
