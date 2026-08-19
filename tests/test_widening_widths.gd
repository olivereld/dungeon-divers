extends SceneTree

## Test de Widening con múltiples anchos (Fase 20 - Verification Hardening)
## Verifica que el ensanchamiento de corredores no invade salas ajenas
## para corridor_width = 1, 2, 3

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

const TEST_SEEDS: Array[int] = [
	3196820195,
	148285204,
	352896113,
	100001,
	100002
]

func _init() -> void:
	print("--- Running test_widening_widths (Phase 20 Hardening) ---")
	test_widening_preserves_room_ownership()
	print("[PASS] test_widening_widths completed successfully!")
	quit(0)

func test_widening_preserves_room_ownership() -> void:
	var pipeline := _DungeonPipelineScript.new()
	
	for seed_val in TEST_SEEDS:
		for width in [1, 2, 3]:
			var config := _DungeonConfigScript.new()
			config.seed = seed_val
			config.use_fixed_seed = true
			config.mission_depth = 5
			config.corridor_width = width
			
			var result: DungeonResult = pipeline.generate(config, 5, true)
			assert(result != null, "Generation must succeed for seed %d width %d" % [seed_val, width])
			
			# Verificar que NO hay invasiones de salas por corredores
			var invasions: int = _count_corridor_invasions(result)
			assert(invasions == 0, "Seed %d width %d must have 0 invasions (got %d)" % [seed_val, width, invasions])
			
			# Verificar que NO hay third-room touches
			var third_room: int = _count_third_room_touches(result)
			assert(third_room == 0, "Seed %d width %d must have 0 third-room touches (got %d)" % [seed_val, width, third_room])
			
			# Verificar exactamente 1 boss
			var boss_count: int = _count_boss_rooms(result)
			assert(boss_count == 1, "Seed %d width %d must have exactly 1 boss (got %d)" % [seed_val, width, boss_count])
			
			# Verificar 100% conectividad
			var walkable: int = result.grid.count_walkable_cells()
			var start_room := _get_start_room(result)
			assert(start_room != null, "Start room must exist for seed %d width %d" % [seed_val, width])
			var df := _compute_distance_field(result.grid, start_room.get_center())
			assert(df.size() == walkable, "Seed %d width %d must have 100%% reachable (%d/%d)" % [seed_val, width, df.size(), walkable])
			
			print("  [OK] Seed %d | Width %d | Rooms %d | Invasions 0 | Boss %d | Reachable %d/%d" % [
				seed_val, width, result.rooms.size(), boss_count, df.size(), walkable
			])
	
	print("  [OK] All seeds passed widening tests for widths 1, 2, 3 (0 invasions, 0 third-room touches)")

func _count_corridor_invasions(result: DungeonResult) -> int:
	var invasions: int = 0
	var grid := result.grid
	
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			if grid.get_cell(p) == CellGrid.CellType.CORRIDOR:
				var owner: int = grid.get_room_owner(p)
				if owner != -1:
					invasions += 1
	
	return invasions

func _count_third_room_touches(result: DungeonResult) -> int:
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

func _count_boss_rooms(result: DungeonResult) -> int:
	var count: int = 0
	for r in result.rooms:
		if r != null and r.room_type == &"boss":
			count += 1
	return count

func _get_start_room(result: DungeonResult) -> RoomData:
	if result.start_room_id != -1:
		for r in result.rooms:
			if r != null and r.id == result.start_room_id:
				return r
	if not result.rooms.is_empty():
		return result.rooms[0]
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
