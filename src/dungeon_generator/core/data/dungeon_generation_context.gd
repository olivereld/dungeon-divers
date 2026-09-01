class_name DungeonGenerationContext
extends RefCounted

## Contexto de Generación del Dungeon (Fase 2).
## Contenedor puro de estado lógico para una tentativa de generación de mazmorra.
## Encapsula datos de configuración, derivación de semillas, topología, rejilla, semántica y métricas
## sin incluir lógica algorítmica ni dependencias de presentación 3D.

const _DungeonResultScript = preload("res://src/dungeon_generator/core/data/dungeon_result.gd")
const _DungeonChecksumCalculatorScript = preload("res://src/dungeon_generator/core/validation/dungeon_checksum_calculator.gd")

# 1. Configuración y Semillas
var config: DungeonConfig = null
var profile_bundle = null                   # ProfileBundle opcional
var base_seed: int = 0
var attempt: int = 0
var attempt_seed: int = 0
var stage_seeds: Dictionary = {}           # String -> int (seed por etapa)
var repair_seed_chain: Array[Dictionary] = [] # Registro cronológico de reparaciones

# 2. Topología y Espacio
var mission_graph: DungeonGraph = null
var rooms: Array[RoomData] = []
var connections: Array = []                 # Array[RoomConnection]
var entrance_pairs: Array = []              # Array[EntrancePair]
var grid: CellGrid = null
var corridor_paths: Array = []              # Array[CorridorPath]
var doors: Array = []                       # Array[DoorPlacement]
var door_pairs: Array = []                  # Array[DoorPair]

# 3. Semántica y Progresión
var start_room_id: int = -1
var boss_room_id: int = -1
var critical_path_rooms: Array[int] = []
var critical_path_connections: Array[int] = []
var mandatory_connections: Array[int] = []
var depth_map: Dictionary = {}              # int (room_id) -> int (depth)
var key_placements: Array = []              # Array[KeyPlacement]
var locked_doors: Array = []                # Array[LockedDoor]

# 4. Campo de Distancia Canónico y Reservas Espaciales
var distance_field: Dictionary = {}         # Vector2i -> int
var reserved_mask: DungeonReservedMask = null

var placement_tier_3: int = 0
var placement_tier_4: int = 0

	# 5. Métricas, Tiempos y Diagnósticos
var stage_timings_ms: Dictionary = {}       # String -> float
var validation_result: RefCounted = null
var fitness_score: float = 0.0
var metrics: Dictionary = {}
var diagnostics: Dictionary = {}
var is_attempt_failed: bool = false
var failure_reason: String = ""
var failure_type: String = "TRANSIENT"      # "TRANSIENT" o "STRUCTURAL"
var diagnostics_enabled: bool = true        # Controla si se emiten push_warning

func _init(p_config: DungeonConfig = null, p_base_seed: int = 0, p_attempt: int = 0) -> void:
	config = p_config
	base_seed = p_base_seed
	attempt = p_attempt
	attempt_seed = 0
	stage_seeds.clear()
	repair_seed_chain.clear()
	rooms.clear()
	connections.clear()
	entrance_pairs.clear()
	corridor_paths.clear()
	doors.clear()
	door_pairs.clear()
	critical_path_rooms.clear()
	critical_path_connections.clear()
	mandatory_connections.clear()
	depth_map.clear()
	key_placements.clear()
	locked_doors.clear()
	distance_field.clear()
	stage_timings_ms.clear()
	placement_tier_3 = 0
	placement_tier_4 = 0
	metrics.clear()
	diagnostics.clear()
	is_attempt_failed = false
	failure_reason = ""

## Registra el tiempo de ejecución en milisegundos de una etapa.
func record_timing(stage_name: String, elapsed_ms: float) -> void:
	stage_timings_ms[stage_name] = elapsed_ms

## Registra la ejecución de una reparación determinista.
func record_repair(stage: String, seed_used: int, success: bool, details: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"stage": stage,
		"attempt": attempt,
		"seed": seed_used,
		"success": success
	}
	for k in details.keys():
		entry[k] = details[k]
	repair_seed_chain.append(entry)

## Marca el intento actual como fallido para activar reintento limpio.
func mark_attempt_failed(reason: String, failure_type: String = "TRANSIENT") -> void:
	is_attempt_failed = true
	failure_reason = reason
	self.failure_type = failure_type

## Empaqueta el estado actual en un DungeonResult inmutable de transferencia.
func to_dungeon_result() -> DungeonResult:
	var res := _DungeonResultScript.new()
	res.grid = grid
	res.mission_graph = mission_graph
	res.rooms = rooms
	res.connections = connections
	res.entrance_pairs = entrance_pairs
	res.corridor_paths = corridor_paths
	res.doors = doors
	res.door_pairs = door_pairs
	res.validation = validation_result
	res.fitness_score = fitness_score
	res.seed_used = base_seed
	res.floor_number = config.floor_number if config != null else 1
	res.placement_tier_3 = placement_tier_3
	res.placement_tier_4 = placement_tier_4
	
	var total_time: float = 0.0
	for t in stage_timings_ms.values():
		total_time += float(t)
	res.generation_time_ms = total_time

	res.seed_trace = {
		"base_seed": base_seed,
		"final_attempt": attempt,
		"attempt_seed": attempt_seed,
		"stage_seeds": stage_seeds,
		"repair_seed_chain": repair_seed_chain,
		"stage_timings_ms": stage_timings_ms,
		"metrics": metrics,
		"diagnostics": diagnostics
	}
	return res
