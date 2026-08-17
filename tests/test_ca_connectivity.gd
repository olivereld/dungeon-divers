extends SceneTree

const _CellularAutomataScript = preload("res://src/dungeon_generator/core/algorithms/cellular_automata.gd")
const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_ca_connectivity ---")

	var ca = _CellularAutomataScript.new()
	var flood_fill = _FloodFillScript.new()

	# Test 1: Contigüidad Interna de CA en 20 salas aleatorias
	var rng := RandomNumberGenerator.new()
	for seed_val in range(100, 120):
		rng.seed = seed_val
		var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
		var room_rect := Rect2i(5, 5, 20, 20)
		ca.apply(grid, room_rect, rng)

		# Contar componentes conexas dentro del rectángulo de la sala
		var local_regions: Array = []
		var visited: Dictionary = {}
		for y in range(room_rect.position.y, room_rect.end.y):
			for x in range(room_rect.position.x, room_rect.end.x):
				var p := Vector2i(x, y)
				if grid.get_cell(p) == CellGrid.CellType.FLOOR and not visited.has(p):
					var reg := flood_fill._flood_region(grid, p, visited)
					if not reg.is_empty():
						local_regions.append(reg)

		assert(local_regions.size() == 1, "CA room with seed %d must have exactly 1 connected floor region, found %d" % [
			seed_val, local_regions.size()
		])
	print("  [OK] Test 1: Internal floor contiguity verified across 20 randomized CA rooms (100% single component)")

	# Test 2: Eliminación forzada de bolsas/islas aisladas
	var grid2 := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room2 := Rect2i(2, 2, 16, 16)
	var center2 := room2.position + room2.size / 2

	# Crear suelo central
	grid2.set_cell(center2, CellGrid.CellType.FLOOR)
	grid2.set_cell(center2 + Vector2i(1, 0), CellGrid.CellType.FLOOR)

	# Crear bolsas aisladas en esquinas rodeadas de muros
	grid2.set_cell(Vector2i(3, 3), CellGrid.CellType.FLOOR)
	grid2.set_cell(Vector2i(16, 16), CellGrid.CellType.FLOOR)

	# Aplicar garantía de contigüidad
	ca._enforce_contiguous_floor(grid2, room2)

	assert(grid2.get_cell(center2) == CellGrid.CellType.FLOOR, "Center floor must remain FLOOR")
	assert(grid2.get_cell(Vector2i(3, 3)) == CellGrid.CellType.WALL, "Isolated pocket (3,3) must be filled with WALL")
	assert(grid2.get_cell(Vector2i(16, 16)) == CellGrid.CellType.WALL, "Isolated pocket (16,16) must be filled with WALL")
	print("  [OK] Test 2: Isolated floor pockets cleanly converted to WALL")

	# Test 3: Validación Global 100% Transitable en FloodFill
	var grid3 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	grid3.fill_rect(Rect2i(2, 2, 10, 10), CellGrid.CellType.FLOOR)
	assert(flood_fill.verify_100_percent_walkable_connected(grid3) == true, "Single region grid must return true")

	# Añadir isla desconectada
	grid3.set_cell(Vector2i(25, 25), CellGrid.CellType.FLOOR)
	assert(flood_fill.verify_100_percent_walkable_connected(grid3) == false, "Grid with disconnected island must return false")
	print("  [OK] Test 3: verify_100_percent_walkable_connected strictly catches disconnected islands")

	# Test 4: Diagnóstico Determinista de Regiones
	var r_dummy := RoomData.new(42, Rect2i(20, 20, 8, 8))
	var diag = flood_fill.get_connectivity_diagnostics(grid3, [r_dummy])
	assert(diag["region_count"] == 2, "Must report 2 regions")
	assert(diag["isolated_regions_count"] == 1, "Must report 1 isolated region")
	assert(diag["isolated_regions"].size() == 1, "Must describe 1 isolated region")
	var island_info: Dictionary = diag["isolated_regions"][0]
	assert(island_info["sample_cell"] == Vector2i(25, 25), "Must correctly locate sample cell of island")
	assert(island_info["room_id"] == 42, "Must associate island with containing room ID 42")
	print("  [OK] Test 4: Deterministic connectivity diagnostics report validated")

	# Test 5: Regresión de Generación de Presets
	var pipeline := _DungeonPipelineScript.new()

	# 5.1 Hybrid Dungeon
	var cfg_hybrid: DungeonConfig = preload("res://resources/configs/hybrid_dungeon.tres").duplicate()
	cfg_hybrid.seed = 12345
	cfg_hybrid.use_fixed_seed = true
	var res_hybrid: DungeonResult = pipeline.call("generate", cfg_hybrid, 5, true)
	assert(res_hybrid != null, "Hybrid preset generation must succeed")
	assert(flood_fill.verify_100_percent_walkable_connected(res_hybrid.grid) == true, "Hybrid dungeon must be 100% connected")
	print("  [OK] Test 5.1: Hybrid preset successfully generated and 100% connected")

	# 5.2 Cave Dungeon
	var cfg_cave: DungeonConfig = preload("res://resources/configs/cave_dungeon.tres").duplicate()
	cfg_cave.seed = 67890
	cfg_cave.use_fixed_seed = true
	var res_cave: DungeonResult = pipeline.call("generate", cfg_cave, 5, true)
	assert(res_cave != null, "Cave preset generation must succeed")
	assert(flood_fill.verify_100_percent_walkable_connected(res_cave.grid) == true, "Cave dungeon must be 100% connected")
	print("  [OK] Test 5.2: Cave preset successfully generated and 100% connected")

	# 5.3 Castle Dungeon
	var cfg_castle: DungeonConfig = preload("res://resources/configs/castle_dungeon.tres").duplicate()
	cfg_castle.seed = 112233
	cfg_castle.use_fixed_seed = true
	var res_castle: DungeonResult = pipeline.call("generate", cfg_castle, 5, true)
	assert(res_castle != null, "Castle preset generation must succeed")
	assert(flood_fill.verify_100_percent_walkable_connected(res_castle.grid) == true, "Castle dungeon must be 100% connected")
	print("  [OK] Test 5.3: Castle preset successfully generated and 100% connected")

	# 5.4 Dungeon 128
	var cfg_128: DungeonConfig = preload("res://resources/configs/dungeon_128.tres").duplicate()
	cfg_128.seed = 445566
	cfg_128.use_fixed_seed = true
	var res_128: DungeonResult = pipeline.call("generate", cfg_128, 5, true)
	assert(res_128 != null, "Dungeon 128 preset generation must succeed")
	assert(flood_fill.verify_100_percent_walkable_connected(res_128.grid) == true, "Dungeon 128 must be 100% connected")
	print("  [OK] Test 5.4: Dungeon 128 preset successfully generated and 100% connected")

	print("[PASS] test_ca_connectivity completed successfully with 100% assertions passing!")
	quit(0)
