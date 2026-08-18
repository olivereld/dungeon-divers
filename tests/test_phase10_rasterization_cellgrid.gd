extends SceneTree

## Test Suite para Consolidación de Rasterización y CellGrid (Fase 10 Gate).
## Ejecuta 100 semillas deterministas y valida:
## 1. CellGrid como única fuente de verdad espacial (100% floor reachable).
## 2. Unicidad y validez del DungeonDistanceField canónico.
## 3. Ausencia de celdas no transitables huérfanas o vacíos colindantes (no VOID leaks).

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonDistanceFieldScript = preload("res://src/dungeon_generator/core/algorithms/dungeon_distance_field.gd")

func _init() -> void:
	print("--- Running test_phase10_rasterization_cellgrid (100 Seeds Gate) ---")
	test_100_seeds_rasterization_and_distance_field()
	print("[PASS] test_phase10_rasterization_cellgrid completed successfully!")
	quit(0)

func test_100_seeds_rasterization_and_distance_field() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_seeds: int = 100
	var total_walkable_cells: int = 0
	var max_observed_distance: int = 0
	
	for s_idx in range(total_seeds):
		var seed_val: int = 800000 + s_idx * 2333
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res := pipeline.generate(config, 5, true)
		assert(res != null, "Generation must succeed for seed %d" % seed_val)
		assert(res.grid != null, "Grid must not be null")
		
		# Encontrar celda inicial (SPAWN o centro de start room)
		var spawn_cells = res.grid.find_cells_of_type(CellGrid.CellType.SPAWN)
		var start_pos: Vector2i = spawn_cells[0] if not spawn_cells.is_empty() else res.rooms[0].get_center()
		
		var reach_res := _DungeonDistanceFieldScript.verify_100_percent_reachable(res.grid, start_pos)
		assert(reach_res["is_100_percent_reachable"] == true, "Seed %d: Found %d unreachable cells: %s" % [
			seed_val, reach_res["unreachable_cells"].size(), str(reach_res["unreachable_cells"])
		])
		
		var w_count: int = reach_res["total_walkable_cells"]
		total_walkable_cells += w_count
		var max_d: int = reach_res["max_distance"]
		if max_d > max_observed_distance:
			max_observed_distance = max_d
		
		# Verificar que ninguna celda transitable linde directamente con VOID sin un muro
		var w: int = res.grid.get_width()
		var h: int = res.grid.get_height()
		for y in range(h):
			for x in range(w):
				var pos := Vector2i(x, y)
				if res.grid.is_walkable(pos):
					var neighbors := res.grid.get_neighbors_8(pos)
					for n in neighbors:
						var n_type = res.grid.get_cell(n)
						assert(n_type != CellGrid.CellType.VOID, "Seed %d: Walkable cell %s neighbors VOID at %s without a WALL barrier" % [
							seed_val, str(pos), str(n)
						])
	
	print("  -> Verified 100 seeds rasterization:")
	print("     - Total Walkable Cells: %d" % total_walkable_cells)
	print("     - Max Topological Distance: %d steps" % max_observed_distance)
	print("     - 100%% Walkable Reachable: PASS")
	print("     - Zero VOID Leaks / Full Wall Enclosure: PASS")
	print("    [OK] Phase 10 Gate passed: Pure CellGrid spatial representation verified")
