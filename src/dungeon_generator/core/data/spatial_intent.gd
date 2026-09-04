class_name SpatialIntent
extends RefCounted

## Objeto de datos inmutable que representa la intención espacial semántica de un nodo de misión.
## Define QUÉ significa el nodo espacialmente (rol, progresión, ancla de ramificación),
## sin contener datos geométricos físicos (Rect2i, CellGrid, RoomData).

const ROLE_START: StringName = &"start"
const ROLE_MAIN_PATH: StringName = &"main_path"
const ROLE_SIDE_PATH: StringName = &"side_path"
const ROLE_BOSS: StringName = &"boss"
const ROLE_GOAL: StringName = &"goal"
const ROLE_OPTIONAL: StringName = &"optional"

var _node_id: int = -1
var _path_role: StringName = &""
var _progression_factor: float = 0.0
var _depth: int = 0
var _main_path_index: int = -1
var _main_path_anchor: int = -1
var _is_sealed: bool = false

var node_id: int:
	get:
		return _node_id
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_node_id = val

var path_role: StringName:
	get:
		return _path_role
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_path_role = val

var progression_factor: float:
	get:
		return _progression_factor
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_progression_factor = val

var depth: int:
	get:
		return _depth
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_depth = val

var main_path_index: int:
	get:
		return _main_path_index
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_main_path_index = val

var main_path_anchor: int:
	get:
		return _main_path_anchor
	set(val):
		assert(not _is_sealed, "SpatialIntent is sealed and immutable.")
		if not _is_sealed:
			_main_path_anchor = val

func _init(
	p_node_id: int = -1,
	p_path_role: StringName = &"",
	p_progression_factor: float = 0.0,
	p_depth: int = 0,
	p_main_path_index: int = -1,
	p_main_path_anchor: int = -1
) -> void:
	_node_id = p_node_id
	_path_role = p_path_role
	_progression_factor = p_progression_factor
	_depth = p_depth
	_main_path_index = p_main_path_index
	_main_path_anchor = p_main_path_anchor

## Sella la instancia para garantizar inmutabilidad estricta.
func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func is_on_main_path() -> bool:
	return _path_role == ROLE_START or _path_role == ROLE_MAIN_PATH or _path_role == ROLE_BOSS or _path_role == ROLE_GOAL

func to_debug_string() -> String:
	return "[SpatialIntent node=%d role=%s prog=%.2f depth=%d main_idx=%d anchor=%d]" % [
		_node_id, _path_role, _progression_factor, _depth, _main_path_index, _main_path_anchor
	]
