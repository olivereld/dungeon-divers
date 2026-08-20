class_name DungeonFloorData
extends RefCounted

## Contenedor exclusivo de datos lógicos y topológicos de un piso individual (Fase 10).
## 100% puro: Cero dependencias de nodos 3D, Presentation ni GridMap.

var floor_number: int = 0
var grid: CellGrid = null
var rooms: Array = []
var connections: Array = []
var corridor_paths: Array = []
var door_pairs: Array = []
var stairs: Array = []
var seed_used: int = 0
var metadata: Dictionary = {}

func _init(
	p_floor_number: int = 0,
	p_grid: CellGrid = null,
	p_rooms: Array = [],
	p_door_pairs: Array = [],
	p_stairs: Array = []
) -> void:
	floor_number = p_floor_number
	grid = p_grid
	rooms = p_rooms
	door_pairs = p_door_pairs
	stairs = p_stairs

## Añade un anclaje de escalera al piso.
func add_stair(stair: StairData) -> void:
	if stair != null and not stairs.has(stair):
		stairs.append(stair)

## Retorna el StairData ubicado en una celda específica (o null si no hay).
func get_stair_at(cell: Vector2i) -> StairData:
	for st in stairs:
		if st != null and st.cell == cell:
			return st
	return null

## Retorna true si el piso posee al menos una escalera.
func has_stairs() -> bool:
	return not stairs.is_empty()

## Crea una instancia de DungeonFloorData a partir de un DungeonResult existente.
static func from_dungeon_result(res: DungeonResult, p_stairs: Array = []) -> DungeonFloorData:
	if res == null:
		return null
	var floor_data := DungeonFloorData.new(
		res.floor_number,
		res.grid,
		res.rooms,
		res.door_pairs,
		p_stairs
	)
	floor_data.connections = res.connections
	floor_data.corridor_paths = res.corridor_paths if "corridor_paths" in res else []
	floor_data.seed_used = res.seed_used
	floor_data.metadata = res.metadata.duplicate(true)
	return floor_data

func _to_string() -> String:
	return "DungeonFloorData(Floor=%d, Rooms=%d, Doors=%d, Stairs=%d)" % [
		floor_number, rooms.size(), door_pairs.size(), stairs.size()
	]
