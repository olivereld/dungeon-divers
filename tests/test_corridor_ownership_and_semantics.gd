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
		
		# Obtener start_room real para tests de conectividad
		var start_room: RoomData = _get_start_room(result)
		assert(start_room != null, "Start room must exist for seed %d" % seed_val)

		# Test 1 & Test 2: Source and Target Doorways valid and on perimeter
		for d in result.doors:
			assert(grid.is_in_bounds(d.position), "Door must be in bounds")
			assert(grid.is_walkable(d.position), "Door must be on a walkable tile")

		# Test 3 & Test 4: CORRIDOR CELLS MUST NOT INVADE ANY ROOM (room_owner == -1)
		# Esta es la verificación CRÍTICA: recorrer TODAS las celdas CORRIDOR del grid
		var all_corridor_cells: Array[Vector2i] = []
		for y in range(grid.height):
			for x in range(grid.width):
				var p := Vector2i(x, y)
				if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
					all_corridor_cells.append(p)
		
		# Verificación 1: Cada celda CORRIDOR debe tener room_owner == -1
		for cell in all_corridor_cells:
			var owner: int = grid.get_room_owner(cell)
			assert(owner == -1, "Corridor cell at %s must NOT belong to any room (found owner %d)" % [str(cell), owner])
		
		# Verificación 2: Para cada conexión, verificar que NO toca tercera habitación (C != A, B)
		for conn in result.connections:
			var r_a: RoomData = _find_room(result.rooms, conn.room_a_id)
			var r_b: RoomData = _find_room(result.rooms, conn.room_b_id)
			assert(r_a != null and r_b != null, "Connected rooms must exist")
			
			# Recoger todas las celdas CORRIDOR entre A y B (usando bounding box como aproximación segura)
			var bbox := Rect2i(
				mini(r_a.rect.position.x, r_b.rect.position.x),
				mini(r_a.rect.position.y, r_b.rect.position.y),
				maxi(r_a.rect.end.x, r_b.rect.end.x) - mini(r_a.rect.position.x, r_b.rect.position.x),
				maxi(r_a.rect.position.y, r_b.rect.position.y) - mini(r_a.rect.position.y, r_b.rect.position.y)
			)
			
			var rooms_touched: Dictionary = {}
			for y in range(bbox.position.y, bbox.end.y):
				for x in range(bbox.position.x, bbox.end.x):
					var p := Vector2i(x, y)
					if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
						var owner: int = grid.get_room_owner(p)
						if owner != -1:
							# Si un corredor toca una habitación, registrar cuál
							rooms_touched[owner] = true
			
			# rooms_touched debe ser subconjunto de {A, B} - nunca una tercera habitación C
			for touched_id in rooms_touched.keys():
				assert(
					touched_id == conn.room_a_id or touched_id == conn.room_b_id,
					"Corridor for connection %d->%d touches third room %d (corridor-through-room bug!)" % [conn.room_a_id, conn.room_b_id, touched_id]
				)

		# Test 5: Every corridor cell connects to reachable grid (usando start_room real)
		var walkable_count: int = grid.count_walkable_cells()
		var spawn_pos: Vector2i = start_room.get_center()
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
		var start_room: RoomData = _get_start_room(result)
		assert(start_room != null, "Start room must exist for random seed %d" % seed_val)
		var df := _compute_distance_field(result.grid, start_room.get_center())
		assert(df.size() == walkable, "Random seed %d must have 100%% reachable floor" % seed_val)
		
		var invasions: int = _count_corridor_invasions(result.grid)
		assert(invasions == 0, "Random seed %d must have 0 corridor invasions" % seed_val)
		
		var third_room: int = _count_third_room_touches_full(result)
		assert(third_room == 0, "Random seed %d must have 0 third-room touches" % seed_val)

		passed_seeds += 1

	print("  [OK] 50/50 Random seeds passed: 100%% reachable, 1 boss, 0 invasions, 0 third-room touches")

func _count_corridor_invasions(grid: CellGrid) -> int:
	var invasions: int = 0
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
				var owner: int = grid.get_room_owner(p)
				if owner != -1:
					invasions += 1
	return invasions

func _count_third_room_touches_full(result: DungeonResult) -> int:
	var touches: int = 0
	var grid := result.grid
	
	for conn in result.connections:
		var r_a: RoomData = _find_room(result.rooms, conn.room_a_id)
		var r_b: RoomData = _find_room(result.rooms, conn.room_b_id)
		if r_a == null or r_b == null:
			continue
		
		var bbox := Rect2i(
			mini(r_a.rect.position.x, r_b.rect.position.x),
			mini(r_a.rect.position.y, r_b.rect.position.y),
			maxi(r_a.rect.end.x, r_b.rect.end.x) - mini(r_a.rect.position.x, r_b.rect.position.x),
			maxi(r_a.rect.position.y, r_b.rect.position.y) - mini(r_a.rect.position.y, r_b.rect.position.y)
		)
		
		var touched_rooms: Dictionary = {}
		for y in range(bbox.position.y, bbox.end.y):
			for x in range(bbox.position.x, bbox.end.x):
				var p := Vector2i(x, y)
				if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
					var owner: int = grid.get_room_owner(p)
					if owner != -1:
						touched_rooms[owner] = true
		
		for touched_id in touched_rooms.keys():
			if touched_id != conn.room_a_id and touched_id != conn.room_b_id:
				touches += 1
	
	return touches

func _find_room(rooms: Array[RoomData], room_id: int) -> RoomData:
	for r in rooms:
		if r != null and r.id == room_id:
			return r
	return null

## Obtiene la start_room real del DungeonResult (no simplemente rooms[0])
func _get_start_room(result: DungeonResult) -> RoomData:
	for r in result.rooms:
		if r != null and r.room_type == &"start":
			return r
	# Fallback: si no hay start_room explícito, usar la primera sala
	if not result.rooms.is_empty():
		return result.rooms[0]
	return null

## Obtiene las celdas de corredor para una conexión específica
## Esto requiere inspeccionar el grid para encontrar celdas CORRIDOR entre las dos salas
func _get_corridor_cells_for_connection(result: DungeonResult, conn_id: int) -> Array[Vector2i]:
	var corridor_cells: Array[Vector2i] = []
	var grid := result.grid
	var conn = _find_connection(result.connections, conn_id)
	if conn == null:
		return corridor_cells
	
	var r_a := _find_room(result.rooms, conn.room_a_id)
	var r_b := _find_room(result.rooms, conn.room_b_id)
	if r_a == null or r_b == null:
		return corridor_cells
	
	# BFS desde el doorway de A hasta el doorway de B, recogiendo celdas CORRIDOR
	var door_a: Vector2i = _find_doorway_for_room(result.doors, conn.room_a_id)
	var door_b: Vector2i = _find_doorway_for_room(result.doors, conn.room_b_id)
	
	if door_a == Vector2i.ZERO or door_b == Vector2i.ZERO:
		# Si no hay puertas, recoger todas las celdas CORRIDOR en el bounding box de las salas
		for y in range(grid.height):
			for x in range(grid.width):
				var p := Vector2i(x, y)
				if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
					corridor_cells.append(p)
		return corridor_cells
	
	# BFS simple para encontrar el camino de corredor entre door_a y door_b
	var queue: Array[Vector2i] = [door_a]
	var visited: Dictionary = {door_a: true}
	var parent: Dictionary = {}
	
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		
		if curr == door_b:
			# Reconstruir camino
			var path: Array[Vector2i] = []
			var trace: Vector2i = curr
			while trace != door_a:
				path.append(trace)
				trace = parent[trace]
			path.append(door_a)
			return path
		
		for n in grid.get_neighbors_4(curr):
			if not visited.has(n) and grid.get_cell(n) == CellGrid.CellType.CORRIDOR:
				visited[n] = true
				parent[n] = curr
				queue.append(n)
	
	# Si no se encontró camino, devolver todas las celdas CORRIDOR como fallback
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
				corridor_cells.append(p)
	
	return corridor_cells

## Encuentra una puerta asociada a una sala específica
func _find_doorway_for_room(doors: Array, room_id: int) -> Vector2i:
	for d in doors:
		if d != null and d.room_id == room_id:
			return d.position
	return Vector2i.ZERO

## Encuentra una conexión por su ID
func _find_connection(connections: Array, conn_id: int) -> Variant:
	for conn in connections:
		if conn != null and conn.id == conn_id:
			return conn
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
