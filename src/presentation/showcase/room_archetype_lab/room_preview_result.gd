class_name RoomPreviewResult
extends RefCounted

## Resultado completo de la generación aislada de una habitación en el laboratorio.
## Contiene referencias al contexto, geometría particionada, composición y jerarquía 3D.

const _RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")

var request: _RoomPreviewRequestScript = null
var room_context: _PresentationRoomContextScript = null
var room_geometry: _PresentationRoomGeometryScript = null
var composition: _DecorationCompositionScript = null
var room_root: Node3D = null

var diagnostics: Dictionary = {}
var success: bool = true
var error_message: String = ""

func _init(
	p_request: _RoomPreviewRequestScript = null,
	p_success: bool = true,
	p_error: String = ""
) -> void:
	request = p_request
	success = p_success
	error_message = p_error

static func create_error(p_request: _RoomPreviewRequestScript, p_error: String) -> RefCounted:
	var res = new(p_request, false, p_error)
	return res
