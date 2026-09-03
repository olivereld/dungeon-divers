class_name DungeonSemanticResult
extends RefCounted

## Contenedor semántico único e inmutable de la experiencia jugable de la mazmorra (Fase 6).
## Encapsula: start, boss/goal, main_path, objectives, keys, locks, optional objectives y validación semántica.
## Inmutable tras invocar seal(): prohíbe cualquier mutación posterior y propaga el sellado a sus componentes.

const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")

# 1. Trazabilidad y Semillas
var base_seed: int = 0
var attempt: int = 0
var attempt_seed: int = 0
var seed_trace: Array[Dictionary] = []

# 2. Referencias Físicas / Topológicas de Solo Lectura
var grid: CellGrid = null
var rooms: Array = [] # Array[RoomData]
var connections: Array = [] # Array[RoomConnection]
var entrance_pairs: Array = [] # Array[EntrancePair]
var corridor_paths: Array = [] # Array[CorridorPath]
var door_pairs: Array = [] # Array[DoorPair]

# 3. Estructura Semántica y Camino Crítico (Start / Boss / Main Path)
var start_room_id: int = -1
var start_node_id: int = -1
var boss_room_id: int = -1
var boss_node_id: int = -1
var main_path: Array[int] = []                    # Secuencia canónica de nodos o salas
var critical_path_rooms: Array[int] = []         # Habitaciones en la ruta canónica Start -> Boss
var critical_path_connections: Array[int] = []   # Conexiones en la ruta canónica Start -> Boss
var mandatory_connections: Array[int] = []       # Aristas puente (bridges) que aíslan Start de Boss
var depth_map: Dictionary = {}                   # room_id -> int distancia en aristas

# 4. Gameplay y Objetivos
var keys: Array = []                             # Array[KeyData]
var locks: Array = []                            # Array[LockData]
var objectives: Array = []                       # Array[ObjectiveData]

# 5. Arquetipo Arquitectónico y Propósitos de Sala
var archetype_id: StringName = &""
var dungeon_archetype: int = 0
var dungeon_archetype_name: String = "GENERIC"
var room_purposes: Dictionary = {}               # room_id (int) -> StringName

func get_archetype_id() -> StringName:
	if not archetype_id.is_empty():
		return archetype_id
	if not dungeon_archetype_name.is_empty() and dungeon_archetype_name != "GENERIC":
		return StringName(dungeon_archetype_name.to_lower())
	return &"necropolis"

# 6. Estado, Validación Semántica y Sellado
var gameplay_valid: bool = false
var gameplay_diagnostics: Dictionary = {}
var validation_result: RefCounted = null          # GameplayValidationResult formal
var is_committed: bool = false
var _is_sealed: bool = false

func seal() -> void:
	if _is_sealed:
		return
	_is_sealed = true
	is_committed = true

	# Propagar inmutabilidad a los datos internos
	for obj in objectives:
		if obj != null and obj.has_method("seal"):
			obj.seal()
	for k in keys:
		if k != null and k.has_method("seal"):
			k.seal()
	for l in locks:
		if l != null and l.has_method("seal"):
			l.seal()

func is_sealed() -> bool:
	return _is_sealed

func mark_committed() -> void:
	seal()

# Getters de conveniencia
func get_start() -> Dictionary:
	return { "room_id": start_room_id, "node_id": start_node_id }

func get_boss() -> Dictionary:
	return { "room_id": boss_room_id, "node_id": boss_node_id }

func get_validation_result() -> RefCounted:
	return validation_result

func get_main_path() -> Array[int]:
	if not main_path.is_empty():
		return main_path
	return critical_path_rooms

func get_optional_objectives() -> Array:
	var result: Array = []
	for obj in objectives:
		if obj != null and not obj.required:
			result.append(obj)
	return result

func get_mandatory_objectives() -> Array:
	var result: Array = []
	for obj in objectives:
		if obj != null and obj.required:
			result.append(obj)
	return result

func get_room_purpose(room_id: int) -> StringName:
	return _RoomPurposeScript.resolve_id(room_purposes.get(room_id, &"generic"))

func get_room_purpose_name(room_id: int) -> String:
	return str(get_room_purpose(room_id)).to_upper()

func get_purpose_distribution() -> Dictionary:
	var dist: Dictionary = {}
	for r_id in room_purposes:
		var p: StringName = _RoomPurposeScript.resolve_id(room_purposes[r_id])
		dist[p] = int(dist.get(p, 0)) + 1
	return dist

func get_rooms_by_purpose(purpose: Variant) -> Array[int]:
	var target_p: StringName = _RoomPurposeScript.resolve_id(purpose)
	var result: Array[int] = []
	for r_id in room_purposes:
		if _RoomPurposeScript.resolve_id(room_purposes[r_id]) == target_p:
			result.append(int(r_id))
	result.sort()
	return result

func get_key_by_id(key_id: int) -> KeyData:
	for k in keys:
		if k.key_id == key_id:
			return k
	return null

func get_lock_by_connection_id(conn_id: int) -> LockData:
	for l in locks:
		if l.connection_id == conn_id:
			return l
	return null

func get_objectives_by_type(p_type: int) -> Array:
	var result: Array = []
	for obj in objectives:
		if obj.type == p_type:
			result.append(obj)
	return result

func to_debug_string() -> String:
	var s := "=== DUNGEON SEMANTIC RESULT (BaseSeed: %d, Attempt: %d, Valid: %s, Sealed: %s) ===\n" % [
		base_seed, attempt, str(gameplay_valid), str(_is_sealed)
	]
	s += "Archetype: %s (ID: %d)\n" % [dungeon_archetype_name, dungeon_archetype]
	s += "Start Room: %d (Node: %d), Boss Room: %d (Node: %d)\n" % [start_room_id, start_node_id, boss_room_id, boss_node_id]
	s += "Main Path (%d): %s\n" % [get_main_path().size(), str(get_main_path())]
	s += "Critical Path Rooms (%d): %s\n" % [critical_path_rooms.size(), str(critical_path_rooms)]
	s += "Critical Path Conns (%d): %s\n" % [critical_path_connections.size(), str(critical_path_connections)]
	s += "Mandatory Conns / Bridges (%d): %s\n" % [mandatory_connections.size(), str(mandatory_connections)]
	s += "Keys (%d): %s\n" % [keys.size(), str(keys.map(func(k): return k.to_debug_string()))]
	s += "Locks (%d): %s\n" % [locks.size(), str(locks.map(func(l): return l.to_debug_string()))]
	s += "Objectives (%d): %s\n" % [objectives.size(), str(objectives.map(func(o): return o.to_debug_string()))]

	if not room_purposes.is_empty():
		s += "\n--- Room Purposes Mapping (%d Rooms) ---\n" % room_purposes.size()
		var sorted_room_ids: Array = room_purposes.keys()
		sorted_room_ids.sort()
		for r_id in sorted_room_ids:
			var p_name: String = get_room_purpose_name(int(r_id))
			s += "  Room %d -> %s\n" % [int(r_id), p_name]

	if not gameplay_diagnostics.is_empty():
		s += "\nDiagnostics: %s\n" % JSON.stringify(gameplay_diagnostics)
	return s
