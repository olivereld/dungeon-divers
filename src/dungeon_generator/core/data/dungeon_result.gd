class_name DungeonResult
extends RefCounted

## Contenedor lógico del resultado completo de una generación de mazmorra.
## 100% puro: no depende de nodos visuales, GridMap ni de la escena 3D.

var grid: CellGrid = null
var mission_graph: DungeonGraph = null
var rooms: Array[RoomData] = []
var connections: Array = []
var entrance_pairs: Array = [] # Array[EntrancePair]
var corridor_paths: Array = [] # Array[CorridorPath]
var validation: RefCounted = null
var fitness_score: float = 0.0
var seed_used: int = 0
var floor_number: int = 1
var generation_time_ms: float = 0.0
var metadata: Dictionary = {}

func to_debug_string() -> String:
	var s := "=== DUNGEON RESULT (Seed: %d, Floor: %d, Fitness: %.4f) ===\n" % [seed_used, floor_number, fitness_score]
	s += "Rooms: %d, Connections: %d, EntrancePairs: %d, Corridors: %d\n" % [
		rooms.size(), connections.size(), entrance_pairs.size(), corridor_paths.size()
	]
	for r in rooms:
		s += "  Room %d: rect=(%d,%d %dx%d) type=%s\n" % [r.id, r.rect.position.x, r.rect.position.y, r.rect.size.x, r.rect.size.y, r.room_type]
	for ep in entrance_pairs:
		if ep != null:
			s += "  %s\n" % ep.to_debug_string()
	for cp in corridor_paths:
		if cp != null:
			s += "  %s\n" % cp.to_debug_string()
	if grid != null:
		s += "\n--- CellGrid ASCII ---\n" + grid.to_debug_string()
	return s
