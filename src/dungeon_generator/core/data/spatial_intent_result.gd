class_name SpatialIntentResult
extends RefCounted

## Contenedor agregado inmutable para la intención espacial de todos los nodos de un MissionGraph.
## Sella la intención semántica completa antes de ser entregada a CompositionStrategy.

const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")

var _start_node_id: int = -1
var _terminal_node_id: int = -1
var _main_path: Array[int] = []
var _intents_by_node: Dictionary = {} # node_id -> SpatialIntent
var _valid: bool = false
var _is_sealed: bool = false

var start_node_id: int:
	get:
		return _start_node_id
	set(val):
		assert(not _is_sealed, "SpatialIntentResult is sealed.")
		if not _is_sealed:
			_start_node_id = val

var terminal_node_id: int:
	get:
		return _terminal_node_id
	set(val):
		assert(not _is_sealed, "SpatialIntentResult is sealed.")
		if not _is_sealed:
			_terminal_node_id = val

var main_path: Array[int]:
	get:
		return _main_path.duplicate()
	set(val):
		assert(not _is_sealed, "SpatialIntentResult is sealed.")
		if not _is_sealed:
			_main_path = val.duplicate()

var valid: bool:
	get:
		return _valid
	set(val):
		assert(not _is_sealed, "SpatialIntentResult is sealed.")
		if not _is_sealed:
			_valid = val

func add_intent(intent: SpatialIntent) -> void:
	assert(not _is_sealed, "SpatialIntentResult is sealed.")
	if not _is_sealed and intent != null:
		_intents_by_node[intent.node_id] = intent

func get_intent(node_id: int) -> SpatialIntent:
	return _intents_by_node.get(node_id, null)

func has_intent(node_id: int) -> bool:
	return _intents_by_node.has(node_id)

func is_main_path(node_id: int) -> bool:
	var intent: SpatialIntent = get_intent(node_id)
	return intent != null and intent.is_on_main_path()

func get_anchor_for_node(node_id: int) -> int:
	var intent: SpatialIntent = get_intent(node_id)
	return intent.main_path_anchor if intent != null else -1

func get_all_node_ids() -> Array[int]:
	var ids: Array[int] = []
	for k in _intents_by_node.keys():
		ids.append(int(k))
	return ids

func size() -> int:
	return _intents_by_node.size()

## Sella el resultado y todos los SpatialIntent que contiene.
func seal() -> void:
	if _is_sealed:
		return
	_is_sealed = true
	for intent in _intents_by_node.values():
		if intent is SpatialIntent:
			intent.seal()

func is_sealed() -> bool:
	return _is_sealed

func to_debug_string() -> String:
	var s := "=== SpatialIntentResult (valid=%s, start=%d, terminal=%d, main_path=%s) ===\n" % [
		str(_valid), _start_node_id, _terminal_node_id, str(_main_path)
	]
	for intent in _intents_by_node.values():
		s += "  %s\n" % intent.to_debug_string()
	return s
