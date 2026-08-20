extends SceneTree

## Test suite para validar el algoritmo de scoring y colocación no destructiva de escaleras (FloorConnectionPlanner).

const FloorConnectionPlanner = preload("res://src/dungeon_generator/core/multilevel/floor_connection_planner.gd")
const DungeonFloorData = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")
const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DoorPlacement = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const DoorPair = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const FloorConnection = preload("res://src/dungeon_generator/core/data/floor_connection.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_stair_candidate_scoring (Candidate Selection) ---")
	print("==================================================================")

	var planner := FloorConnectionPlanner.new()

	# 1. Crear Floor A sintético (20x20) con una habitación de 8x8
	var grid_a := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(4, 4, 8, 8), &"start")
	grid_a.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)

	# Puertas asociadas
	var door_a := DoorPlacement.new(0, 0, Vector2i(4, 8), 0, Vector2i(5, 8), Vector2i(3, 8))
	var door_b := DoorPlacement.new(0, 1, Vector2i(14, 8), 2, Vector2i(13, 8), Vector2i(15, 8))
	var dp_a := DoorPair.new(0, door_a, door_b)

	var floor_a := DungeonFloorData.new(0, grid_a, [room_a], [dp_a], [])

	# 2. Crear Floor B sintético (20x20) con una habitación de 8x8
	var grid_b := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room_b := RoomData.new(0, Rect2i(6, 6, 8, 8), &"explore")
	grid_b.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	var floor_b := DungeonFloorData.new(1, grid_b, [room_b], [], [])

	# 3. Planificar escaleras entre Floor A y Floor B
	var vconn: FloorConnection = planner.plan_stairs_between_floors(floor_a, floor_b, 42)
	assert(vconn != null, "Vertical connection must be established")
	assert(vconn.from_floor == 0 and vconn.to_floor == 1)

	# 4. Validar que las celdas elegidas no solapan con la puerta
	assert(vconn.from_cell != dp_a.door_a.position, "Stair cell must not block door position")
	assert((vconn.from_cell - dp_a.door_a.position).length() > 1.0, "Stair cell must have margin from door")

	# 5. Validar que los CellGrid tienen los tipos de celda de escalera correctos
	assert(grid_a.get_cell(vconn.from_cell) == CellGrid.CellType.STAIRS_UP, "Floor A stair to F1 must be STAIRS_UP")
	assert(grid_b.get_cell(vconn.to_cell) == CellGrid.CellType.STAIRS_DOWN, "Floor B stair to F0 must be STAIRS_DOWN")

	# 6. Validar que los DTOs de piso registraron los StairData correspondientes
	assert(floor_a.stairs.size() == 1)
	assert(floor_b.stairs.size() == 1)
	assert(floor_a.stairs[0].cell == vconn.from_cell)
	assert(floor_b.stairs[0].cell == vconn.to_cell)

	print("  [OK] Escaleras planificadas con scoring inteligente sin bloqueos de puertas.")
	print("==================================================================")
	print("[PASS] test_stair_candidate_scoring completado con 100% éxito!")
	print("==================================================================")
	quit(0)
