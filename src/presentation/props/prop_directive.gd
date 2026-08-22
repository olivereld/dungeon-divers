class_name PropDirective
extends RefCounted

## Directiva de materialización para un Room Prop.
## Representa la salida inmutable del PropResolver para ser consumida por PropSpawner.
## Contiene identificación, estilo, transform 3D, celdas ocupadas lógicas y modo de colisión.

const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")

var prop_id: StringName = &""
var room_id: int = -1
var style: _PropStyleScript = null
var world_position: Vector3 = Vector3.ZERO
var rotation_degrees_y: float = 0.0
var occupied_cells: Array[Vector2i] = []
var placement_mode: int = _PropPlacementModeScript.Mode.FLOOR
var collision_mode: int = _PropCollisionModeScript.Mode.BLOCKING

func _init(
	p_id: StringName = &"",
	p_room: int = -1,
	p_style: _PropStyleScript = null,
	p_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_cells: Array[Vector2i] = [],
	p_placement: int = _PropPlacementModeScript.Mode.FLOOR,
	p_collision: int = _PropCollisionModeScript.Mode.BLOCKING
) -> void:
	prop_id = p_id
	room_id = p_room
	style = p_style
	world_position = p_pos
	rotation_degrees_y = p_rot_y
	occupied_cells = p_cells
	placement_mode = p_placement
	collision_mode = p_collision
