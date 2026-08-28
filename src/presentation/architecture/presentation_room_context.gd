class_name PresentationRoomContext
extends RefCounted

## Contexto inmutable de presentación por habitación.
## Conecta la información espacial (RoomData), la semántica (RoomPurpose) y el estilo arquitectónico
## resuelto (ArchitecturalPresentationProfile) para consumo del pipeline visual.
## 100% puro: no contiene nodos de escena ni mallas 3D.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

var room_id: int = -1
var rect: Rect2i = Rect2i()
var purpose: StringName = &"generic"
var profile: _ArchitecturalPresentationProfileScript = null
var role: _PresentationRoomRoleScript.Role = _PresentationRoomRoleScript.Role.EXPLORE
var room_profile: RefCounted = null # ProfileRoom

var role_name: String:
	get:
		return _PresentationRoomRoleScript.to_name(role)

func _init(
	p_room_id: int = -1,
	p_rect: Rect2i = Rect2i(),
	p_purpose: Variant = &"generic",
	p_profile: _ArchitecturalPresentationProfileScript = null,
	p_role: _PresentationRoomRoleScript.Role = _PresentationRoomRoleScript.Role.EXPLORE,
	p_room_profile: RefCounted = null
) -> void:
	room_id = p_room_id
	rect = p_rect
	purpose = _RoomPurposeScript.resolve_id(p_purpose)
	profile = p_profile
	role = p_role
	room_profile = p_room_profile

func to_debug_string() -> String:
	var prof_str := profile.to_debug_string() if profile != null else "None"
	var r_prof_str := str(room_profile.id) if room_profile != null and "id" in room_profile else "None"
	return "RoomContext(ID: %d, Role: %s, Purpose: %s, Profile: %s, RoomProfile: %s)" % [
		room_id, role_name, str(purpose), prof_str, r_prof_str
	]
