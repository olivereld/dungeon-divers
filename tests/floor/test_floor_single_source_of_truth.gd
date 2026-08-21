extends SceneTree

const DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_floor_single_source_of_truth (DungeonFloorGenerator) ---")
	print("==================================================================")

	var floor_gen = DungeonFloorGeneratorScript.new()
	var grid = CellGridScript.new(3, 3, CellGridScript.CellType.FLOOR)

	var patterns = [
		FloorTileConfigScript.PatternType.STYLIZED_STONE,
		FloorTileConfigScript.PatternType.COBBLESTONE,
		FloorTileConfigScript.PatternType.BRICK,
		FloorTileConfigScript.PatternType.SMOOTH_SLABS,
		FloorTileConfigScript.PatternType.RUINED_TILES
	]

	for pat in patterns:
		var cfg = FloorTileConfigScript.new()
		cfg.pattern = pat
		cfg.tile_size = 2.0
		cfg.margin = 0.04
		cfg.seed = 1337

		var res = floor_gen.generate_floor_surface(grid, cfg, 1337)
		assert(res != null, "FAIL: Floor result must not be null")
		assert(not res.clusters.is_empty(), "FAIL: Clusters must not be empty for pattern %d" % pat)
		var total_v: int = 0
		for cl in res.clusters:
			if cl.mesh != null:
				for s in range(cl.mesh.get_surface_count()):
					var arr = cl.mesh.surface_get_arrays(s)
					total_v += arr[Mesh.ARRAY_VERTEX].size()

		assert(total_v > 0, "FAIL: Vertices must be generated for pattern %d" % pat)
		print("  [OK] Floor Pattern %d generated %d clusters (%d total vertices)" % [pat, res.clusters.size(), total_v])

	print("[PASS] test_floor_single_source_of_truth completed successfully.")
	quit(0)
