class_name DungeonMultiFloorResult
extends RefCounted

## Resultado inmutable de la mazmorra completa multinivel (Fase 10).
## Contiene todos los pisos (DungeonFloorData) y sus conexiones verticales (FloorConnection).

var master_seed: int = 0
var floors: Dictionary = {} ## floor_number (int) -> DungeonFloorData
var vertical_connections: Array[FloorConnection] = []
var seed_trace: Dictionary = {}
var is_valid: bool = false
var total_generation_time_ms: float = 0.0
var metadata: Dictionary = {}

func _init(
	p_master_seed: int = 0,
	p_floors: Dictionary = {},
	p_vertical_connections: Array[FloorConnection] = []
) -> void:
	master_seed = p_master_seed
	floors = p_floors
	vertical_connections = p_vertical_connections

## Registra un piso en la colección multinivel.
func add_floor(floor_data: DungeonFloorData) -> void:
	if floor_data != null:
		floors[floor_data.floor_number] = floor_data

## Retorna el piso con el número especificado (o null si no existe).
func get_floor(floor_number: int) -> DungeonFloorData:
	return floors.get(floor_number, null)

## Retorna la cantidad total de pisos generados.
func get_floor_count() -> int:
	return floors.size()

## Retorna la lista ordenada de números de piso.
func get_floor_numbers() -> Array[int]:
	var nums: Array[int] = []
	for k in floors.keys():
		nums.append(int(k))
	nums.sort()
	return nums

## Añade una conexión vertical entre pisos.
func add_vertical_connection(conn: FloorConnection) -> void:
	if conn != null and not vertical_connections.has(conn):
		vertical_connections.append(conn)

## Retorna todas las conexiones verticales incidentes en un piso dado.
func get_vertical_connections_for_floor(floor_number: int) -> Array[FloorConnection]:
	var conns: Array[FloorConnection] = []
	for c in vertical_connections:
		if c != null and (c.from_floor == floor_number or c.to_floor == floor_number):
			conns.append(c)
	return conns

## Busca y retorna un StairData por su ID en cualquiera de los pisos.
func get_stair_data(stair_id: String) -> StairData:
	if stair_id.is_empty():
		return null
	for f_data in floors.values():
		if f_data is DungeonFloorData:
			for st in f_data.stairs:
				if st != null and st.stair_id == stair_id:
					return st
	return null

func to_debug_string() -> String:
	var s := "=== DUNGEON MULTI-FLOOR RESULT (Master Seed: %d, Floors: %d, Vertical Conns: %d) ===\n" % [
		master_seed, get_floor_count(), vertical_connections.size()
	]
	for f_num in get_floor_numbers():
		var f: DungeonFloorData = get_floor(f_num)
		s += "  Floor %d: %s\n" % [f_num, str(f)]
	for vc in vertical_connections:
		if vc != null:
			s += "  Vertical Conn: %s\n" % str(vc)
	return s
