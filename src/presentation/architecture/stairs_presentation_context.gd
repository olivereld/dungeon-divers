class_name StairsPresentationContext
extends RefCounted

## Contexto inmutable de presentación arquitectónica para escaleras de ascenso y descenso.
## Vincula el punto de conexión vertical (StairData) con el perfil arquitectónico de la sala
## anfitriona y el piso destino para determinar el estilo de peldaños y barandillas (Stone vs Wood).
## 100% puro: no contiene nodos 3D ni muta CellGrid.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

var stair_id: String = ""
var connection_id: String = ""
var floor_number: int = 0
var target_floor: int = -1
var cell: Vector2i = Vector2i.ZERO
var room_id: int = -1
var source_profile: _ArchitecturalPresentationProfileScript = null
var target_profile: _ArchitecturalPresentationProfileScript = null
var is_downward: bool = false
var orientation: float = 0.0

func _init(
	p_stair_id: String = "",
	p_conn_id: String = "",
	p_floor_num: int = 0,
	p_target_floor: int = -1,
	p_cell: Vector2i = Vector2i.ZERO,
	p_room_id: int = -1,
	p_src_prof: _ArchitecturalPresentationProfileScript = null,
	p_dst_prof: _ArchitecturalPresentationProfileScript = null,
	p_is_downward: bool = false,
	p_orientation: float = 0.0
) -> void:
	stair_id = p_stair_id
	connection_id = p_conn_id
	floor_number = p_floor_num
	target_floor = p_target_floor
	cell = p_cell
	room_id = p_room_id
	source_profile = p_src_prof
	target_profile = p_dst_prof
	is_downward = p_is_downward
	orientation = p_orientation

func to_debug_string() -> String:
	var src_str := source_profile.to_debug_string() if source_profile != null else "None"
	return "StairsPresentationContext(ID: %s, Floor: %d -> %d, Room: %d, Dir: %s, SrcProf: %s)" % [
		stair_id, floor_number, target_floor, room_id, "DOWN" if is_downward else "UP", src_str
	]
