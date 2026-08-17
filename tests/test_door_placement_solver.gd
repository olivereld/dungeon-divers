extends SceneTree

const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorTransitionValidatorScript = preload("res://src/dungeon_generator/core/validation/door_transition_validator.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("--- Running test_door_placement_solver (Migrated to DoorTransitionValidator) ---")

	# Grid de prueba 10x10
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	var room := RoomData.new(0, Rect2i(1, 1, 4, 4))
	grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

	# 1. Caso Válido: Transición ROOM (FLOOR) -> DOOR -> CORRIDOR hacia el Este
	grid.set_cell(Vector2i(5, 2), CellGrid.CellType.DOOR)
	grid.set_cell(Vector2i(6, 2), CellGrid.CellType.CORRIDOR)

	var valid_door := _DoorPlacementScript.new(
		0, 0, Vector2i(5, 2), _RoomEntranceScript.EAST, Vector2i(4, 2), Vector2i(6, 2)
	)
	var val_res := _DoorTransitionValidatorScript.validate_local_transition(grid, valid_door, room)
	assert(val_res["is_valid"] == true, "Valid door transition must pass validation")

	# 2. Caso Inválido: Sin corredor exterior
	grid.set_cell(Vector2i(6, 2), CellGrid.CellType.WALL)
	var val_invalid := _DoorTransitionValidatorScript.validate_local_transition(grid, valid_door, room)
	assert(val_invalid["is_valid"] == false, "Door without corridor must fail")
	assert(val_invalid["reason"] == "NO_CORRIDOR_AT_ENTRANCE", "Reason must be NO_CORRIDOR_AT_ENTRANCE")

	print("[PASS] test_door_placement_solver (migrated) succeeded.")
	quit(0)
