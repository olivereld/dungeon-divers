extends SceneTree

## Test unitario para Task 4: Política Inteligente de Puertas y Pasillos Cortos en DoorResolver (Fase Reforced).
## Valida que en pasillos cortos (<= 3 celdas) se coloque como máximo 1 puerta física,
## priorizando la sala de mayor jerarquía (Boss > Treasure > Puzzle > Normal > Start), dejando el otro extremo como OPEN_PASSAGE.

func _init() -> void:
	print("--- Running test_door_resolver_policy ---")
	var ResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	var grid := CellGrid.new(30, 30)
	var r1 := RoomData.new(0, Rect2i(2, 2, 6, 6), &"start")
	var r2 := RoomData.new(1, Rect2i(12, 2, 6, 6), &"boss")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	# Pasillo corto de longitud 2 entre (8, 4) y (11, 4): celdas exteriores (9, 4) y (10, 4)
	grid.set_cell(Vector2i(9, 4), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(10, 4), CellGrid.CellType.CORRIDOR)

	var RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
	var ent_a = RoomEntranceScript.new(0, 1, Vector2i(8, 4), RoomEntranceScript.EAST, Vector2i(7, 4), Vector2i(9, 4))
	var ent_b = RoomEntranceScript.new(1, 1, Vector2i(11, 4), RoomEntranceScript.WEST, Vector2i(12, 4), Vector2i(10, 4))
	var ep = preload("res://src/dungeon_generator/core/data/entrance_pair.gd").new(1, ent_a, ent_b, 0.0)
	var conn = preload("res://src/dungeon_generator/core/data/room_connection.gd").new(1, 0, 1, true)
	var cl_cells: Array[Vector2i] = [Vector2i(9, 4), Vector2i(10, 4)]
	var path = preload("res://src/dungeon_generator/core/data/corridor_path.gd").new(1, 0, 1, cl_cells, cl_cells)

	var cfg := DungeonConfig.new()
	cfg.seed = 12345
	cfg.use_fixed_seed = true

	var res = ResolverScript.resolve_doors(grid, [r1, r2], [ep], [path], [conn], cfg)
	assert(res != null and res.is_valid, "DoorResolver must resolve successfully")
	assert(res.door_pairs.size() == 1, "Must have 1 door pair")
	var dp = res.door_pairs[0]

	# En pasillo corto (length=2), exactamente una puerta debe ser OPEN_PASSAGE y la otra CLOSED_DOOR (o ambas OPEN_PASSAGE según RNG)
	var closed_count: int = 0
	if dp.door_a.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE: closed_count += 1
	if dp.door_b.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE: closed_count += 1

	assert(closed_count <= 1, "Short corridor (length 2) must have AT MOST 1 physical door, got %d" % closed_count)
	assert(dp.door_b.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE, "Boss room door must be prioritized for physical door")
	assert(dp.door_a.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE, "Start room entrance must be OPEN_PASSAGE")
	print("  [OK] Single door allocation for short corridor verified (Boss=CLOSED_DOOR, Start=OPEN_PASSAGE)")

	print("[PASS] test_door_resolver_policy completed successfully!")
	quit(0)
