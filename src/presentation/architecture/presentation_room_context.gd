class_name PresentationRoomContext
extends RefCounted

## Contexto inmutable de presentación por habitación.
## Conecta la información espacial (RoomData), la semántica (RoomPurpose) y el estilo arquitectónico
## resuelto (ArchitecturalPresentationProfile) para consumo del pipeline visual.
## 100% puro: no contiene nodos de escena ni mallas 3D.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")

var room_id: int = -1
var rect: Rect2i = Rect2i()
var purpose: int = 0
var profile: _ArchitecturalPresentationProfileScript = null
var role: _PresentationRoomRoleScript.Role = _PresentationRoomRoleScript.Role.EXPLORE

var role_name: String:
	get:
		return _PresentationRoomRoleScript.to_name(role)

func _init(
	p_room_id: int = -1,
	p_rect: Rect2i = Rect2i(),
	p_purpose: int = 0,
	p_profile: _ArchitecturalPresentationProfileScript = null,
	p_role: _PresentationRoomRoleScript.Role = _PresentationRoomRoleScript.Role.EXPLORE
) -> void:
	room_id = p_room_id
	rect = p_rect
	purpose = p_purpose
	profile = p_profile
	role = p_role

func to_debug_string() -> String:
	var prof_str := profile.to_debug_string() if profile != null else "None"
	return "RoomContext(ID: %d, Role: %s, Purpose: %d, Profile: %s)" % [
		room_id, role_name, purpose, prof_str
	]
