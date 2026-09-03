class_name CorridorPlan
extends RefCounted

## Plan inmutable y sellado de peticiones de pasillos (Corridor Planning).
## Contiene todas las CorridorRequest optimizadas con su rol semántico,
## preferencias de ruteo y restricciones dimensionales para su ejecución en AStarCarver.

const CorridorRequest = preload("res://src/dungeon_generator/core/data/corridor_request.gd")

var _requests: Array[CorridorRequest] = []
var _requests_by_connection: Dictionary = {} # int (connection_id) -> CorridorRequest
var _is_sealed: bool = false

func add_request(req: CorridorRequest) -> void:
	assert(not _is_sealed, "CorridorPlan is sealed and immutable.")
	if not _is_sealed and req != null:
		_requests.append(req)
		_requests_by_connection[req.connection_id] = req

func get_requests() -> Array[CorridorRequest]:
	return _requests.duplicate()

func get_request_for_connection(conn_id: int) -> CorridorRequest:
	return _requests_by_connection.get(conn_id, null)

func size() -> int:
	return _requests.size()

func is_empty() -> bool:
	return _requests.is_empty()

func seal() -> void:
	if _is_sealed:
		return
	_is_sealed = true
	for req in _requests:
		if req != null and req.has_method("seal"):
			req.seal()

func is_sealed() -> bool:
	return _is_sealed

func to_debug_string() -> String:
	var s := "=== CorridorPlan (sealed=%s, count=%d) ===\n" % [str(_is_sealed), _requests.size()]
	for req in _requests:
		s += "  %s\n" % req.to_debug_string()
	return s
