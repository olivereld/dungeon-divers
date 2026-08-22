class_name PresentationRoomGeometry
extends RefCounted

## Vista geométrica particionada y desacoplada de una sala individual.
## Contiene las celdas de suelo, perímetro de muros y el perfil arquitectónico específico de la sala.
## 100% puro: no muta CellGrid ni depende de nodos de escena.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

var room_id: int = -1
var bounds: Rect2i = Rect2i()
var floor_cells: Array[Vector2i] = []
var wall_cells: Array[Vector2i] = []
var door_positions: Array[Vector2i] = []
var profile: _ArchitecturalPresentationProfileScript = null

func _init(
	p_room_id: int = -1,
	p_bounds: Rect2i = Rect2i(),
	p_floor: Array[Vector2i] = [],
	p_wall: Array[Vector2i] = [],
	p_doors: Array[Vector2i] = [],
	p_profile: _ArchitecturalPresentationProfileScript = null
) -> void:
	room_id = p_room_id
	bounds = p_bounds
	floor_cells = p_floor
	wall_cells = p_wall
	door_positions = p_doors
	profile = p_profile
