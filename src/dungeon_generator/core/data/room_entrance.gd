class_name RoomEntrance
extends RefCounted

## Contrato de datos lógico: Representa una entrada física seleccionada en el perímetro de una habitación.
## Estructura pura 2D sin dependencias de GridMap, MeshLibrary o AStar.

enum Side {
	NORTH = 0,
	SOUTH = 1,
	WEST = 2,
	EAST = 3
}

const NORTH = Side.NORTH
const SOUTH = Side.SOUTH
const WEST = Side.WEST
const EAST = Side.EAST

var room_id: int = -1
var connection_id: int = -1
var position: Vector2i = Vector2i.ZERO # Celda de muro en el perímetro (boundary)
var side: int = Side.NORTH

# Coordenadas semánticas de 3 niveles para navegación y verificación
var inner_cell: Vector2i = Vector2i.ZERO   # Dentro de la habitación (suelo)
var boundary_cell: Vector2i = Vector2i.ZERO # En el muro perimetral (= position)
var outer_cell: Vector2i = Vector2i.ZERO   # Fuera de la habitación (futuro corredor A*)

func _init(
	p_room_id: int = -1,
	p_connection_id: int = -1,
	p_pos: Vector2i = Vector2i.ZERO,
	p_side: int = Side.NORTH,
	p_inner: Vector2i = Vector2i.ZERO,
	p_outer: Vector2i = Vector2i.ZERO
) -> void:
	room_id = p_room_id
	connection_id = p_connection_id
	position = p_pos
	side = p_side
	boundary_cell = p_pos
	inner_cell = p_inner
	outer_cell = p_outer

static func side_to_string(s: int) -> String:
	match s:
		Side.NORTH:
			return "NORTH"
		Side.SOUTH:
			return "SOUTH"
		Side.WEST:
			return "WEST"
		Side.EAST:
			return "EAST"
		_:
			return "UNKNOWN"

static func side_to_direction(s: int) -> Vector2i:
	match s:
		Side.NORTH:
			return Vector2i(0, -1)
		Side.SOUTH:
			return Vector2i(0, 1)
		Side.WEST:
			return Vector2i(-1, 0)
		Side.EAST:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO

static func direction_to_side(dir: Vector2i) -> int:
	if absi(dir.x) >= absi(dir.y):
		return Side.EAST if dir.x > 0 else Side.WEST
	else:
		return Side.SOUTH if dir.y > 0 else Side.NORTH

func get_outward_direction() -> Vector2i:
	return side_to_direction(side)

func get_inward_direction() -> Vector2i:
	return -get_outward_direction()

func to_debug_string() -> String:
	return "Entrance(Room: %d, Conn: %d, Pos: %s, Side: %s, Outer: %s)" % [
		room_id, connection_id, str(position), side_to_string(side), str(outer_cell)
	]
