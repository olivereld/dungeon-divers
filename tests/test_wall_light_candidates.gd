extends SceneTree

const WallLightCandidateFinder = preload("res://src/dungeon_lighting/planning/wall_light_candidate_finder.gd")
const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DoorPair = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const DoorPlacement = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const CorridorPath = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const LightPlacement = preload("res://src/dungeon_lighting/data/light_placement.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_light_candidates ---")
	print("==================================================================")

	var grid := CellGrid.new(20, 20)
	var room := RoomData.new(1, Rect2i(4, 4, 6, 6))
	for y in range(4, 10):
		for x in range(4, 10):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)
			grid.set_room_owner(Vector2i(x, y), 1)

	var door_a := DoorPlacement.new(1, 1, Vector2i(7, 4), 0, Vector2i(7, 4), Vector2i(7, 3))
	var door_p := DoorPair.new(1, door_a, null)

	var finder := WallLightCandidateFinder.new()
	var candidates = finder.find_room_wall_candidates(room, grid, [door_p], 1)

	assert(candidates.size() > 0, "Candidates found on room perimeter")
	for c in candidates:
		assert(c.cell != Vector2i(7, 4), "Door cell (7,4) must NOT be a light candidate")
		assert(grid.is_walkable(c.cell), "Candidate must be inside walkable floor")
		assert(c.room_id == 1, "Candidate associated with room 1")
		assert(c.wall_side >= 0 and c.wall_side <= 3, "Valid wall side")

	# Test para pasillo
	var corridor := CorridorPath.new(1, 1, 2)
	corridor.carved_cells = [
		Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4),
		Vector2i(14, 4), Vector2i(15, 4), Vector2i(16, 4), Vector2i(17, 4)
	]
	for c in corridor.carved_cells:
		grid.set_cell(c, CellGrid.CellType.CORRIDOR)

	var corr_candidates = finder.find_corridor_wall_candidates(corridor, grid)
	assert(corr_candidates.size() > 0, "Corridor wall candidates found")
	for cc in corr_candidates:
		assert(grid.is_walkable(cc.cell), "Candidate must be a corridor cell")
		assert(cc.corridor_id == "1", "Candidate has corridor ID")

	print("==================================================================")
	print("[PASS] test_wall_light_candidates completado con éxito!")
	print("==================================================================")
	quit(0)
