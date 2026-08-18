class_name DungeonDoorManifest
extends Resource

## Manifiesto geométrico para la colocación física de puertas en Presentation (Fase 9).
## Libre de estado semántico (cero is_locked) y libre de autoridades espaciales redundantes.
## La posición 3D exacta y orientación se derivan canónicamente mediante GridToWorld.

@export var connection_id: String = ""   ## ID de la conexión lógica asociada
@export var door_id: String = ""         ## ID único del endpoint de puerta (ej: "conn_1_door_a")
@export var cell: Vector2i = Vector2i.ZERO ## Celda transitable donde asienta la puerta
@export var adjacent_cell: Vector2i = Vector2i.ZERO ## Celda vecina hacia donde cruza
@export var side: int = 0                ## Dirección cardinal (Side.NORTH, EAST, SOUTH, WEST)
@export var door_type: int = 0           ## DoorType (0=CLOSED_DOOR, 1=LOCKED_DOOR, 2=OPEN_PASSAGE)

func _init(
	p_conn_id: String = "",
	p_door_id: String = "",
	p_cell: Vector2i = Vector2i.ZERO,
	p_adj_cell: Vector2i = Vector2i.ZERO,
	p_side: int = 0,
	p_door_type: int = 0
) -> void:
	connection_id = p_conn_id
	door_id = p_door_id
	cell = p_cell
	adjacent_cell = p_adj_cell
	side = p_side
	door_type = p_door_type

## Devuelve la orientación angular en radianes (eje Y) derivada de la dirección cardinal 'side'.
func get_orientation_radians() -> float:
	match side:
		0: return 0.0          # NORTH: mira hacia +Z / Sur o normal hacia el norte
		1: return -PI * 0.5    # EAST
		2: return PI           # SOUTH
		3: return PI * 0.5     # WEST
	return 0.0

func to_debug_string() -> String:
	return "DungeonDoorManifest(DoorID: %s, Conn: %s, Cell: %s, Adj: %s, Side: %d)" % [
		door_id, connection_id, str(cell), str(adjacent_cell), side
	]
