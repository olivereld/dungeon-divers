class_name EntranceCandidate
extends RefCounted

## Candidato evaluable para entrada a una habitación en una orientación específica.

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

var room_id: int = -1
var side: int = 0
var position: Vector2i = Vector2i.ZERO
var inner_cell: Vector2i = Vector2i.ZERO
var boundary_cell: Vector2i = Vector2i.ZERO
var outer_cell: Vector2i = Vector2i.ZERO

func _init(
	p_room_id: int = -1,
	p_side: int = 0,
	p_pos: Vector2i = Vector2i.ZERO,
	p_inner: Vector2i = Vector2i.ZERO,
	p_outer: Vector2i = Vector2i.ZERO
) -> void:
	room_id = p_room_id
	side = p_side
	position = p_pos
	boundary_cell = p_pos
	inner_cell = p_inner
	outer_cell = p_outer

func to_entrance(connection_id: int) -> RoomEntrance:
	return _RoomEntranceScript.new(
		room_id,
		connection_id,
		position,
		side,
		inner_cell,
		outer_cell
	)
