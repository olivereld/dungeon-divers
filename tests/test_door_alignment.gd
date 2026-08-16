extends SceneTree

func _init() -> void:
	print("--- Running test_door_alignment ---")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.grid_width = 64
	config.grid_height = 64
	config.corridor_style = "LShaped"

	for seed_val in [100, 200, 300, 400, 500]:
		config.seed = seed_val
		config.use_fixed_seed = true
		var result: DungeonPipeline.DungeonResult = pipeline.generate(config, 5, true)
		assert(result != null, "Result should not be null")

		var grid := result.grid

		# 1. Verificar que las puertas estén en umbrales reales
		var doors: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.DOOR)
		for door_pos in doors:
			var n4 := grid.get_neighbors_4(door_pos)
			var has_walkable: bool = false
			for n in n4:
				if grid.is_walkable(n):
					has_walkable = true
					break
			assert(has_walkable, "Door at %s must connect to walkable area" % str(door_pos))

		# 2. Verificar que las puertas bloqueadas (LOCKED_DOOR) no estén flotando
		var locked_doors: Array[Vector2i] = grid.find_cells_of_type(CellGrid.CellType.LOCKED_DOOR)
		for ld in locked_doors:
			assert(grid.count_walkable_neighbors(ld, true) > 0, "Locked door at %s must be attached to walkable area" % str(ld))

	print("[PASS] test_door_alignment succeeded.")
	quit(0)
