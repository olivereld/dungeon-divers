extends SceneTree

## Test Suite de Invariantes Estructurales y Contratos de Datos (Fase 1).
## Valida que cada estructura contenga exclusivamente sus datos autoritativos y
## no duplique responsabilidades de otros subsistemas.

const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DungeonResultScript = preload("res://src/dungeon_generator/core/data/dungeon_result.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase1_structural_invariants ---")
	test_room_data_pure_contract()
	test_room_connection_topology_authority()
	test_cell_grid_spatial_authority()
	test_door_pair_contract()
	test_dungeon_result_contract()
	print("[PASS] test_phase1_structural_invariants completed successfully!")
	quit(0)

func test_room_data_pure_contract() -> void:
	print("  -> Testing RoomData pure contract (identity + geometry + basic semantics)...")
	var room := _RoomDataScript.new(1, Rect2i(5, 5, 10, 8), &"combat")
	assert(room.id == 1, "Room id must match")
	assert(room.rect == Rect2i(5, 5, 10, 8), "Room rect must match")
	assert(room.room_type == &"combat", "Room type must match")
	assert(room.get_area() == 80, "Area must match width * height")
	assert(room.get_center() == Vector2i(10, 9), "Center must match")
	
	# Verificar que RoomData no tiene campos de conexiones duplicadas
	var prop_names: Array[String] = []
	for p in room.get_property_list():
		prop_names.append(p.name)
	
	assert(not prop_names.has("connections"), "RoomData must NOT have legacy 'connections' property")
	assert(not prop_names.has("connected_room_ids"), "RoomData must NOT have legacy 'connected_room_ids' property")
	print("    [OK] RoomData has pure scope with no topology duplication")

func test_room_connection_topology_authority() -> void:
	print("  -> Testing RoomConnection topology authority...")
	var conn := _RoomConnectionScript.new(0, 1, 2, true)
	assert(conn.id == 0, "Connection id must match")
	assert(conn.room_a_id == 1, "room_a_id must match")
	assert(conn.room_b_id == 2, "room_b_id must match")
	assert(conn.is_required == true, "is_required must match")
	print("    [OK] RoomConnection correctly owns graph topology edges")

func test_cell_grid_spatial_authority() -> void:
	print("  -> Testing CellGrid sole spatial authority...")
	var grid := _CellGridScript.new(16, 16, _CellGridScript.CellType.WALL)
	assert(grid.get_width() == 16 and grid.get_height() == 16, "Dimensions must match")
	assert(grid.get_cell(Vector2i(0, 0)) == _CellGridScript.CellType.WALL, "Default cell must be WALL")
	grid.set_cell(Vector2i(2, 2), _CellGridScript.CellType.FLOOR)
	assert(grid.is_walkable(Vector2i(2, 2)) == true, "Floor must be walkable")
	assert(grid.is_solid(Vector2i(2, 2)) == false, "Floor must not be solid")
	assert(grid.is_walkable(Vector2i(0, 0)) == false, "Wall must not be walkable")
	print("    [OK] CellGrid is the single spatial source of truth")

func test_door_pair_contract() -> void:
	print("  -> Testing DoorPair definitive door contract...")
	var d_a := _DoorPlacementScript.new(0, 1, Vector2i(5, 5), 0, Vector2i(5, 6), Vector2i(5, 4))
	var d_b := _DoorPlacementScript.new(0, 2, Vector2i(10, 10), 2, Vector2i(10, 9), Vector2i(10, 11))
	var pair := _DoorPairScript.new(0, d_a, d_b)
	assert(pair.is_valid() == true, "DoorPair must be valid with 2 distinct room endpoints")
	print("    [OK] DoorPair represents finalized doors for connection")

func test_dungeon_result_contract() -> void:
	print("  -> Testing DungeonResult immutable transport container...")
	var res := _DungeonResultScript.new()
	assert(res.grid == null, "Initial grid must be null")
	assert(res.rooms.is_empty(), "Initial rooms must be empty")
	assert(res.connections.is_empty(), "Initial connections must be empty")
	print("    [OK] DungeonResult adheres to clean transport contract")
