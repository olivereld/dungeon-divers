extends SceneTree

## Test unitario para Task 2: Integración de Formas Arquitectónicas en DungeonPipeline.
## Valida que en algoritmos Hybrid/BSP/CellularAutomata, las salas no se degraden a líneas o gusanos.

func _init() -> void:
	print("--- Running test_pipeline_room_shapes ---")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.seed = 812297351
	config.use_fixed_seed = true
	config.algorithm = "Hybrid"

	var res: DungeonResult = pipeline.generate(config, 5, false)
	assert(res != null and res.grid != null, "Generation must succeed")

	for r in res.rooms:
		var floor_count: int = 0
		for y in range(r.rect.position.y, r.rect.end.y):
			for x in range(r.rect.position.x, r.rect.end.x):
				if res.grid.get_cell(Vector2i(x, y)) == CellGrid.CellType.FLOOR or res.grid.get_cell(Vector2i(x, y)) == CellGrid.CellType.DOOR:
					floor_count += 1

		var total_area: int = r.rect.size.x * r.rect.size.y
		var ratio: float = float(floor_count) / float(total_area)
		assert(ratio >= 0.50, "Room ID %d (%s) area ratio %f is too low! Must be >= 50%%" % [r.id, r.room_type, ratio])
		print("  [OK] Room ID %d (%s): Area=%d/%d (%.1f%%)" % [r.id, r.room_type, floor_count, total_area, ratio * 100.0])

	print("[PASS] test_pipeline_room_shapes completed successfully!")
	quit(0)
