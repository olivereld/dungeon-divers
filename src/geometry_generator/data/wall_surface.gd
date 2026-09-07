class_name WallSurface
extends RefCounted

## Metadatos canónicos de una superficie exterior arquitectónica entre una celda de muro y un espacio transitable.
## Elimina la necesidad de deducir normales invertidas en decoradores y garantiza coherencia espacial.

enum OwnerType {
	NONE = 0,
	ROOM = 1,
	CORRIDOR = 2
}

var cell: Vector2i = Vector2i.ZERO
var neighbor_cell: Vector2i = Vector2i.ZERO
var side: int = 0
var normal: Vector3 = Vector3.ZERO
var owner_type: int = OwnerType.NONE
var room_id: int = -1

func _init(
	p_cell: Vector2i = Vector2i.ZERO,
	p_neighbor: Vector2i = Vector2i.ZERO,
	p_side: int = 0,
	p_normal: Vector3 = Vector3.ZERO,
	p_owner_type: int = OwnerType.NONE,
	p_room_id: int = -1
) -> void:
	cell = p_cell
	neighbor_cell = p_neighbor
	side = p_side
	normal = p_normal
	owner_type = p_owner_type
	room_id = p_room_id
