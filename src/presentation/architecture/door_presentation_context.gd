class_name DoorPresentationContext
extends RefCounted

## Contexto inmutable de presentación arquitectónica para una puerta o portal.
## Relaciona un DoorPair / DungeonDoorManifest con las salas de origen y destino conectadas
## y sus respectivos perfiles arquitectónicos (source_profile y target_profile).
## 100% puro: no contiene nodos de escena ni muta CellGrid.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

var connection_id: int = -1
var door_id: String = ""
var source_room_id: int = -1
var target_room_id: int = -1
var source_profile: _ArchitecturalPresentationProfileScript = null
var target_profile: _ArchitecturalPresentationProfileScript = null
var position: Vector2i = Vector2i.ZERO
var adjacent_position: Vector2i = Vector2i.ZERO

func _init(
	p_conn_id: int = -1,
	p_door_id: String = "",
	p_src_id: int = -1,
	p_dst_id: int = -1,
	p_src_prof: _ArchitecturalPresentationProfileScript = null,
	p_dst_prof: _ArchitecturalPresentationProfileScript = null,
	p_pos: Vector2i = Vector2i.ZERO,
	p_adj_pos: Vector2i = Vector2i.ZERO
) -> void:
	connection_id = p_conn_id
	door_id = p_door_id
	source_room_id = p_src_id
	target_room_id = p_dst_id
	source_profile = p_src_prof
	target_profile = p_dst_prof
	position = p_pos
	adjacent_position = p_adj_pos

func to_debug_string() -> String:
	var src_str := source_profile.to_debug_string() if source_profile != null else "None"
	var dst_str := target_profile.to_debug_string() if target_profile != null else "None"
	return "DoorPresentationContext(ID: %s, Conn: %d, Room %d -> Room %d, SrcProf: %s, DstProf: %s)" % [
		door_id, connection_id, source_room_id, target_room_id, src_str, dst_str
	]
