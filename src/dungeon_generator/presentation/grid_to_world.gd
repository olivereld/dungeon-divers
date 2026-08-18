class_name GridToWorld
extends RefCounted

## Centraliza de forma canónica la proyección espacial entre coordenadas 2D (CellGrid),
## números de piso (Fase 10 - Verticalidad) y el espacio 3D continuo del motor.
## Contrato Canónico:
## - Rejilla X ➔ Mundo X
## - Rejilla Y ➔ Mundo Z
## - Piso Y   ➔ Mundo Y = floor_number * floor_height

## Convierte un número de piso en la cota de altura Y en metros.
static func floor_to_world_y(floor_number: int, floor_height: float = 6.0) -> float:
	return float(floor_number) * floor_height

## Proyección de la esquina inferior-izquierda de una celda a coordenadas 3D.
static func cell_to_world_3d(
	cell: Vector2i,
	floor_number: int = 0,
	tile_size: float = 2.0,
	floor_height: float = 6.0
) -> Vector3:
	return Vector3(
		float(cell.x) * tile_size,
		floor_to_world_y(floor_number, floor_height),
		float(cell.y) * tile_size
	)

## Proyección del centro exacto de una celda a coordenadas 3D en un piso determinado.
static func get_cell_center_world_3d(
	cell: Vector2i,
	floor_number: int = 0,
	tile_size: float = 2.0,
	floor_height: float = 6.0,
	y_offset: float = 0.0
) -> Vector3:
	var half: float = tile_size * 0.5
	var base_y: float = floor_to_world_y(floor_number, floor_height)
	return Vector3(
		(float(cell.x) * tile_size) + half,
		base_y + y_offset,
		(float(cell.y) * tile_size) + half
	)

## Proyección inversa: dado un punto 3D continuo, deriva el número de piso y la celda discreta.
static func world_to_cell_and_floor(
	world_pos: Vector3,
	tile_size: float = 2.0,
	floor_height: float = 6.0
) -> Dictionary:
	var floor_num: int = 0
	if floor_height > 0.0:
		floor_num = int(floorf((world_pos.y + (floor_height * 0.5)) / floor_height))
	
	var cell: Vector2i = Vector2i.ZERO
	if tile_size > 0.0:
		cell = Vector2i(
			int(floorf(world_pos.x / tile_size)),
			int(floorf(world_pos.z / tile_size))
		)
	
	return {
		"floor_number": floor_num,
		"cell": cell
	}

# ==============================================================================
# MÉTODOS 2D / COMPATIBILIDAD RETROACTIVA
# ==============================================================================

static func cell_to_world(cell: Vector2i, tile_size: float = 2.0, height: float = 0.0) -> Vector3:
	return Vector3(cell.x * tile_size, height, cell.y * tile_size)

static func world_to_cell(world_pos: Vector3, tile_size: float = 2.0) -> Vector2i:
	if tile_size <= 0.0:
		return Vector2i.ZERO
	return Vector2i(roundi(world_pos.x / tile_size), roundi(world_pos.z / tile_size))

static func get_cell_center_world(cell: Vector2i, tile_size: float = 2.0, height: float = 0.0) -> Vector3:
	var half: float = tile_size * 0.5
	return Vector3(cell.x * tile_size + half, height, cell.y * tile_size + half)
