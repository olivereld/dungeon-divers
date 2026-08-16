extends SceneTree

func _init() -> void:
	print("--- Running test_room_connectivity across 20 random dungeons ---")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.corridor_width = 2
	config.algorithm = "Hybrid"

	var flood := FloodFill.new()

	for i in range(20):
		config.seed = randi()
		var result: DungeonPipeline.DungeonResult = pipeline.generate(config, 8, true)
		assert(result != null, "Pipeline must successfully generate a dungeon for seed %d" % config.seed)

		var grid := result.grid
		var rooms := result.rooms

		# 1. Verificar que todas las habitaciones estén conectadas entre sí
		var all_rooms_ok: bool = flood.verify_all_rooms_reachable(grid, rooms)
		assert(all_rooms_ok, "Seed %d: All rooms must be 100%% reachable (no isolated boxes!)" % result.seed_used)

		# 2. Verificar camino crítico Spawn -> Objetivo
		var critical_ok: bool = flood.verify_critical_path(grid)
		assert(critical_ok, "Seed %d: Critical path must be reachable" % result.seed_used)

		# 3. Verificar que cada habitación tenga al menos una conexión transitable en su perímetro
		for r in rooms:
			var has_open_door: bool = false
			var outer: Rect2i = r.expanded(1)
			for y in range(outer.position.y, outer.end.y):
				for x in range(outer.position.x, outer.end.x):
					var p := Vector2i(x, y)
					if (p.x == outer.position.x or p.x == outer.end.x - 1 or p.y == outer.position.y or p.y == outer.end.y - 1):
						if grid.is_walkable(p):
							has_open_door = true
							break
				if has_open_door:
					break
			assert(has_open_door, "Seed %d: Room %d (%s) must have at least 1 open doorway in perimeter!" % [result.seed_used, r.id, r.room_type])

		print("  [OK] Dungeon %d (Seed: %d, Rooms: %d, Fitness: %.2f) 100%% connected." % [
			i + 1, result.seed_used, rooms.size(), result.fitness_score
		])

	print("[PASS] test_room_connectivity succeeded: 0 isolated rooms across all tests.")
	quit(0)
