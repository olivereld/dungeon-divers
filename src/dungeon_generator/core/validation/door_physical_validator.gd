class_name DoorPhysicalValidator
extends RefCounted

## Validador físico y topológico de puertas: verifica presencia de jambas sólidas y área libre.

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

const DIRS4: Array[Vector2i] = [
	Vector2i(0, -1), # NORTH
	Vector2i(1, 0),  # EAST
	Vector2i(0, 1),  # SOUTH
	Vector2i(-1, 0)  # WEST
]

## Valida que la puerta esté flanqueada en ambos lados perpendiculares por celdas sólidas (muros o límites).
static func validate_door_jambs(grid: CellGrid, door_pos: Vector2i, side: int) -> bool:
	if grid == null:
		return false

	var jamb_a := Vector2i.ZERO
	var jamb_b := Vector2i.ZERO

	match side:
		_RoomEntranceScript.NORTH, _RoomEntranceScript.SOUTH:
			# Cruce vertical (Norte-Sur): jambas laterales a la izquierda (Oeste) y derecha (Este)
			jamb_a = door_pos + Vector2i(-1, 0)
			jamb_b = door_pos + Vector2i(1, 0)
		_RoomEntranceScript.WEST, _RoomEntranceScript.EAST:
			# Cruce horizontal (Este-Oeste): jambas laterales arriba (Norte) y abajo (Sur)
			jamb_a = door_pos + Vector2i(0, -1)
			jamb_b = door_pos + Vector2i(0, 1)
		_:
			return true

	# Ambas jambas deben ser sólidas (NO transitables) o estar fuera de los límites del mapa
	var jamb_a_solid: bool = not grid.is_in_bounds(jamb_a) or not grid.is_walkable(jamb_a)
	var jamb_b_solid: bool = not grid.is_in_bounds(jamb_b) or not grid.is_walkable(jamb_b)

	return jamb_a_solid and jamb_b_solid

## Calcula el área libre local (número de celdas transitables conectadas) en un radio determinado.
static func get_local_free_area(grid: CellGrid, origin: Vector2i, radius: int = 2) -> int:
	if grid == null or not grid.is_in_bounds(origin) or not grid.is_walkable(origin):
		return 0

	var queue: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: true}
	var count: int = 0

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		count += 1

		for d in DIRS4:
			var n: Vector2i = curr + d
			if visited.has(n):
				continue
			if grid.is_in_bounds(n) and grid.is_walkable(n):
				visited[n] = true
				if (abs(n.x - origin.x) + abs(n.y - origin.y)) <= radius:
					queue.push_back(n)

	return count
