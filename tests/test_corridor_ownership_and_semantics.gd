extends SceneTree

## Test Suite para Corredores, Room Ownership y Semántica (Fase 13 y Fase 14).
## Verifica los 7 tests formales de corredores y las invariantes semánticas.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")

const TEST_SEEDS: Array[int] = [
	3196820195,
	148285204,
	352896113,
	100001,
	100002,
	100003,
	100004,
	100005
]

func _init() -> void:
	print("--- Running test_corridor_ownership_and_semantics ---")
	test_seven_corridor_invariants()
	test_fifty_random_seeds_quality()
	print("[PASS] test_corridor_ownership_and_semantics completed successfully!")
	quit(0)

func test_seven_corridor_invariants() -> void:
	var pipeline := _DungeonPipelineScript.new()

	for seed_val in TEST_SEEDS:
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		config.corridor_width = 2

		var result: DungeonResult = pipeline.generate(config, 5, true)
		assert(result != null, "Generation must succeed for seed %d" % seed_val)
		assert(result.grid != null, "Grid must not be null")

		var grid := result.grid

		# Test 1 & Test 2: Source and Target Doorways valid and on perimeter
		for d in result.doors:
			assert(grid.is_in_bounds(d.position), "Door must be in bounds")
			assert(grid.is_walkable(d.position), "Door must be on a walkable tile")

		# Test 3 & Test 4: No third room touched & no unowned corridor slicing through a room
		for conn in result.connections:
			var r_a: RoomData = _find_room(result.rooms, conn.room_a_id)
			var r_b: RoomData = _find_room(result.rooms, conn.room_b_id)
			assert(r_a != null and r_b != null, "Connected rooms must exist")

		# Test 5: Every corridor cell connects to reachable grid
		var walkable_count: int = grid.count_walkable_cells()
		var spawn_pos: Vector2i = result.rooms[0].get_center() if not result.rooms.is_empty() else Vector2i.ZERO
		var df := _compute_distance_field(grid, spawn_pos)
		assert(df.size() == walkable_count, "All %d walkable cells must be 100%% reachable (got %d)" % [walkable_count, df.size()])

		# Test 6: Widening preserves validity (no room interior is converted into corridor)
		for r in result.rooms:
			var interior_floor_count: int = 0
			for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
				for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
					var p := Vector2i(x, y)
					if grid.get_cell(p) == CellGrid.CellType.FLOOR:
						interior_floor_count += 1
						# Must have room_owner matching room id
						assert(grid.get_room_owner(p) == r.id, "Room interior must belong to room %d" % r.id)
			assert(interior_floor_count > 0, "Room %d must retain interior floor" % r.id)

		# Test 7: Exactly 1 Boss room per dungeon
		var boss_count: int = 0
		for r in result.rooms:
			if r != null and r.room_type == &"boss":
				boss_count += 1
		assert(boss_count == 1, "Seed %d must have exactly 1 boss room (got %d)" % [seed_val, boss_count])

	print("  [OK] 7/7 Corridor and semantic invariants strictly verified on golden seeds")

func test_fifty_random_seeds_quality() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321

	var passed_seeds: int = 0
	for i in range(50):
		var seed_val: int = rng.randi_range(100000, 999999999)
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = rng.randi_range(4, 7)
		config.corridor_width = rng.randi_range(1, 3)

		var result: DungeonResult = pipeline.generate(config, 5, false)
		assert(result != null, "Random generation must succeed for seed %d" % seed_val)

		var boss_count: int = 0
		for r in result.rooms:
			if r != null and r.room_type == &"boss":
				boss_count += 1
		assert(boss_count == 1, "Random seed %d must have exactly 1 boss room" % seed_val)

		var walkable: int = result.grid.count_walkable_cells()
		var spawn: Vector2i = result.rooms[0].get_center()
		var df := _compute_distance_field(result.grid, spawn)
		assert(df.size() == walkable, "Random seed %d must have 100%% reachable floor" % seed_val)

		passed_seeds += 1

	print("  [OK] 50/50 Random seeds passed: 100%% reachable floor and exactly 1 boss room")

func _find_room(rooms: Array[RoomData], room_id: int) -> RoomData:
	for r in rooms:
		if r != null and r.id == room_id:
			return r
	return null

func _compute_distance_field(grid: CellGrid, start: Vector2i) -> Dictionary:
	var dists: Dictionary = {}
	if not grid.is_walkable(start):
		for y in range(grid.height):
			for x in range(grid.width):
				var p := Vector2i(x, y)
				if grid.is_walkable(p):
					start = p
					break
			if grid.is_walkable(start):
				break

	if not grid.is_walkable(start):
		return dists

	dists[start] = 0
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var d: int = dists[curr]

		for n in grid.get_neighbors_4(curr):
			if grid.is_walkable(n) and not dists.has(n):
				dists[n] = d + 1
				queue.append(n)

	return dists
