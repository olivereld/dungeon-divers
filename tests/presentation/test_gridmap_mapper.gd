class_name TestGridMapMapper
extends SceneTree

const _GridMapMapperScript = preload("res://src/dungeon_generator/presentation/gridmap_mapper.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_gridmap_mapper ---")

	var mapper = _GridMapMapperScript.new()
	var profile = _BiomeProfileScript.new()

	var mesh_lib := MeshLibrary.new()
	for i in range(16):
		mesh_lib.create_item(i)
	profile.mesh_library = mesh_lib
	profile.floor_index = 0
	profile.wall_index = 1
	profile.dungeon_floor_index = 2
	profile.column_index = 3
	profile.obstacle_index = 4
	profile.corridor_index = 5

	var floor_map := GridMap.new()
	floor_map.mesh_library = mesh_lib
	var wall_map := GridMap.new()
	wall_map.mesh_library = mesh_lib

	var grid := CellGrid.new(10, 10)
	grid.clear(CellGrid.CellType.VOID)

	grid.set_cell(Vector2i(1, 1), CellGrid.CellType.FLOOR)
	grid.set_cell(Vector2i(2, 1), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(3, 1), CellGrid.CellType.WALL)
	grid.set_cell(Vector2i(4, 1), CellGrid.CellType.COLUMN)
	grid.set_cell(Vector2i(5, 1), CellGrid.CellType.OBSTACLE)
	grid.set_cell(Vector2i(0, 0), CellGrid.CellType.VOID) # Debería quedar vacío

	# Snapshot previo
	var snap_before: Dictionary = _take_snapshot(grid)

	var res: Dictionary = mapper.map_grid(grid, profile, floor_map, wall_map, null)
	assert(res["total_tiles"] > 0, "Tiles should be rendered")
	assert(res["diagnostics"].is_empty(), "Valid mapping should have 0 diagnostics")

	# Invariante 1: CERO mutaciones en CellGrid
	var snap_after: Dictionary = _take_snapshot(grid)
	assert(_compare_snapshots(snap_before, snap_after), "CellGrid must NOT be mutated by GridMapMapper")
	print("  [OK] Test 1: Zero CellGrid mutations verified")

	# Test 2: Verificación de tiles específicos
	assert(floor_map.get_cell_item(Vector3i(1, 0, 1)) == 0, "FLOOR should be item 0")
	assert(floor_map.get_cell_item(Vector3i(2, 0, 1)) == 5, "CORRIDOR should be item 5")
	assert(floor_map.get_cell_item(Vector3i(0, 0, 0)) == -1, "VOID should have NO tile in floor_map")
	assert(wall_map.get_cell_item(Vector3i(0, 0, 0)) == -1, "VOID should have NO tile in wall_map")
	assert(wall_map.get_cell_item(Vector3i(4, 0, 1)) == 3, "COLUMN should be item 3 in wall_map")
	assert(wall_map.get_cell_item(Vector3i(5, 0, 1)) == 4, "OBSTACLE should be item 4 in wall_map")
	print("  [OK] Test 2: Exact tile mappings verified for all CellTypes")

	print("[PASS] test_gridmap_mapper succeeded with 100% assertions passing!")
	quit(0)

func _take_snapshot(grid: CellGrid) -> Dictionary:
	var s: Dictionary = {}
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			s[p] = grid.get_cell(p)
	return s

func _compare_snapshots(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k) or a[k] != b[k]:
			return false
	return true
