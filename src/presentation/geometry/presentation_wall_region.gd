class_name PresentationWallRegion
extends RefCounted

## Región desacoplada para la generación de muros continuos y mampostería.
## Transporta las celdas perimetrales de la sala, el perfil de estilo arquitectónico y el ID de sala.
## 100% puro: no contiene nodos de escena.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

var room_id: int = -1
var wall_cells: Array[Vector2i] = []
var profile: _ArchitecturalPresentationProfileScript = null
var is_corridor: bool = false

func _init(
	p_room_id: int = -1,
	p_walls: Array[Vector2i] = [],
	p_profile: _ArchitecturalPresentationProfileScript = null,
	p_is_corridor: bool = false
) -> void:
	room_id = p_room_id
	wall_cells = p_walls
	profile = p_profile
	is_corridor = p_is_corridor
