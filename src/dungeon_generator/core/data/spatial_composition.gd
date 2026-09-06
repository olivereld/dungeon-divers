class_name SpatialComposition
extends RefCounted

## Representa la composición espacial deseada pre-placement de un MissionGraph.
## Modela la dirección global de progresión, las anclas y factores del camino principal,
## las asignaciones de anclas principales para ramas secundarias, y métricas de densidad y región.
## Inmutable tras invocar seal().
##
## Restricciones:
## - No modifica CellGrid ni RoomData.
## - No coloca salas ni calcula posiciones finales de colisión.
## - No ejecuta A* ni resuelve entradas físicas (entrances).

const REGION_START: StringName = &"region_start"
const REGION_EARLY: StringName = &"region_early"
const REGION_MID: StringName = &"region_mid"
const REGION_LATE: StringName = &"region_late"
const REGION_BOSS: StringName = &"region_boss"
const REGION_BRANCH: StringName = &"region_branch"
const REGION_OPTIONAL: StringName = &"region_optional"
const REGION_MAIN_PATH: StringName = &"region_main_path"

var _progression_direction: Vector2 = Vector2.ZERO
var _main_path_node_ids: Array[int] = []
var _main_path_factors: Dictionary = {} # int -> float
var _main_path_anchor_targets: Dictionary = {} # int -> Vector2
var _branch_anchor_node_ids: Dictionary = {} # int -> int (branch_id -> main_anchor_id)
var _branch_factors: Dictionary = {} # int -> float
var _density_by_node: Dictionary = {} # int -> float
var _region_by_node: Dictionary = {} # int -> StringName
var _is_sealed: bool = false

# ==============================================================================
# PROPIEDADES PÚBLICAS (GETTERS)
# ==============================================================================

var progression_direction: Vector2:
	get:
		return _progression_direction

var main_path_node_ids: Array[int]:
	get:
		return _main_path_node_ids.duplicate()

var main_path_factors: Dictionary:
	get:
		return _main_path_factors.duplicate()

var main_path_anchor_targets: Dictionary:
	get:
		return _main_path_anchor_targets.duplicate()

var branch_anchor_node_ids: Dictionary:
	get:
		return _branch_anchor_node_ids.duplicate()

var branch_factors: Dictionary:
	get:
		return _branch_factors.duplicate()

var density_by_node: Dictionary:
	get:
		return _density_by_node.duplicate()

var region_by_node: Dictionary:
	get:
		return _region_by_node.duplicate()

# ==============================================================================
# API DE CONSULTA (READ-ONLY)
# ==============================================================================

## Retorna el factor de progresión continuo (0.0 a 1.0) para un nodo del camino principal.
## Retorna -1.0 si el nodo no pertenece a la ruta principal.
func get_main_path_factor(node_id: int) -> float:
	return _main_path_factors.get(node_id, -1.0)

## Retorna la posición objetivo de anclaje global (en espacio continuo o de grid) para un nodo.
## Retorna Vector2.ZERO si no existe objetivo explícito asignado.
func get_anchor_target(node_id: int) -> Vector2:
	if _main_path_anchor_targets.has(node_id):
		return _main_path_anchor_targets[node_id]
	return Vector2.ZERO

## Retorna el ID del nodo ancla en la ruta principal del cual depende esta rama secundaria.
## Retorna -1 si el nodo no es una rama secundaria o no tiene ancla.
## Garantía: El ancla retornada siempre es un nodo del camino principal, nunca otra rama.
func get_branch_anchor(node_id: int) -> int:
	return _branch_anchor_node_ids.get(node_id, -1)

## Retorna el factor de progresión relativo de la rama secundaria.
func get_branch_factor(node_id: int) -> float:
	return _branch_factors.get(node_id, 0.0)

## Retorna la densidad espacial objetivo asignada al nodo (default 1.0).
func get_density(node_id: int) -> float:
	return _density_by_node.get(node_id, 1.0)

## Retorna la región semántica asignada al nodo.
func get_region(node_id: int) -> StringName:
	if _region_by_node.has(node_id):
		return _region_by_node[node_id]
	if is_main_path(node_id):
		return REGION_MAIN_PATH
	return REGION_BRANCH

## Retorna verdadero si el nodo pertenece al camino principal.
func is_main_path(node_id: int) -> bool:
	return _main_path_factors.has(node_id)

## Retorna verdadero si el nodo está registrado en la composición.
func has_node(node_id: int) -> bool:
	return _main_path_factors.has(node_id) or _branch_anchor_node_ids.has(node_id)

## Retorna todos los IDs de nodos registrados (main path + branches).
func get_all_node_ids() -> Array[int]:
	var result: Array[int] = []
	for id in _main_path_node_ids:
		if not result.has(id):
			result.append(id)
	for id in _branch_anchor_node_ids.keys():
		var nid: int = int(id)
		if not result.has(nid):
			result.append(nid)
	return result

## Sella la composición espacial, volviéndola estrictamente inmutable.
func seal() -> void:
	_is_sealed = true

## Retorna verdadero si la composición está sellada.
func is_sealed() -> bool:
	return _is_sealed

# ==============================================================================
# MUTADORES (SOLO ANTES DE SEAL)
# ==============================================================================

func set_progression_direction(dir: Vector2) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		_progression_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO

func set_main_path_node_ids(ids: Array[int]) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		_main_path_node_ids = ids.duplicate()

func set_main_path_node(node_id: int, factor: float, anchor_target: Vector2) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		_main_path_factors[node_id] = clampf(factor, 0.0, 1.0)
		_main_path_anchor_targets[node_id] = anchor_target
		if not _main_path_node_ids.has(node_id):
			_main_path_node_ids.append(node_id)

func set_branch_node(node_id: int, main_anchor_id: int, factor: float, anchor_target: Vector2) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		assert(node_id != main_anchor_id, "Branch node cannot anchor to itself.")
		_branch_anchor_node_ids[node_id] = main_anchor_id
		_branch_factors[node_id] = clampf(factor, 0.0, 1.0)
		_main_path_anchor_targets[node_id] = anchor_target

func set_node_density(node_id: int, density: float) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		_density_by_node[node_id] = maxf(density, 0.0)

func set_node_region(node_id: int, region: StringName) -> void:
	assert(not _is_sealed, "SpatialComposition is sealed and immutable.")
	if not _is_sealed:
		_region_by_node[node_id] = region

func to_debug_string() -> String:
	var s := "=== SpatialComposition (sealed=%s, dir=%s, main_path_count=%d, branch_count=%d) ===\n" % [
		str(_is_sealed), str(_progression_direction), _main_path_node_ids.size(), _branch_anchor_node_ids.size()
	]
	s += "  Main Path Nodes:\n"
	for nid in _main_path_node_ids:
		s += "    Node %d: factor=%.3f, target=%s, region=%s, density=%.2f\n" % [
			nid, get_main_path_factor(nid), str(get_anchor_target(nid)), str(get_region(nid)), get_density(nid)
		]
	s += "  Branch Nodes:\n"
	for nid in _branch_anchor_node_ids.keys():
		var id_int: int = int(nid)
		s += "    Node %d: anchor=%d, factor=%.3f, target=%s, region=%s, density=%.2f\n" % [
			id_int, get_branch_anchor(id_int), get_branch_factor(id_int), str(get_anchor_target(id_int)), str(get_region(id_int)), get_density(id_int)
		]
	return s
