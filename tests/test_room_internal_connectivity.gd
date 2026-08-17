extends SceneTree

const _CellularAutomataScript = preload("res://src/dungeon_generator/core/algorithms/cellular_automata.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")

func _init() -> void:
	print("--- Running test_room_internal_connectivity ---")

	var ca := _CellularAutomataScript.new()
	var flood_fill := _FloodFillScript.new()

	# Test 1: validate_room_internal_connectivity detecta salas contiguas vs fragmentadas
	var grid1 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room1 := RoomData.new(0, Rect2i(2, 2, 10, 10))
	grid1.fill_rect(room1.rect, CellGrid.CellType.FLOOR)

	var val1 = _StructuralValidatorScript.validate_room_internal_connectivity(grid1, room1)
	assert(val1["is_valid"] == true, "Solid floor room must be valid")
	assert(val1["region_count"] == 1, "Must have exactly 1 region")

	# Fragmentar deliberadamente la sala creando un muro divisor con una bolsa aislada
	for y in range(2, 12):
		grid1.set_cell(Vector2i(6, y), CellGrid.CellType.WALL) # Muro divisor en medio
	grid1.set_cell(Vector2i(3, 3), CellGrid.CellType.FLOOR) # Isla a la izquierda
	grid1.set_cell(Vector2i(9, 9), CellGrid.CellType.FLOOR) # Isla a la derecha

	var val1_frag = _StructuralValidatorScript.validate_room_internal_connectivity(grid1, room1)
	assert(val1_frag["is_valid"] == false, "Fragmented room must fail validation")
	assert(val1_frag["region_count"] == 2, "Must detect exactly 2 isolated regions")
	assert(val1_frag["reason"] == "FRAGMENTED_ROOM", "Reason must be FRAGMENTED_ROOM")
	print("  [OK] Test 1: validate_room_internal_connectivity correctly differentiates contiguous vs fragmented rooms")

	# Test 2: CellularAutomata genera 0 salas fragmentadas en 30 corridas aleatorias
	var rng := RandomNumberGenerator.new()
	for seed_val in range(500, 530):
		rng.seed = seed_val
		var grid2 := CellGrid.new(40, 40, CellGrid.CellType.WALL)
		var r_rect := Rect2i(4, 4, 18, 18)
		var test_room := RoomData.new(seed_val, r_rect)

		ca.apply(grid2, r_rect, rng)

		var r_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid2, test_room)
		assert(r_val["is_valid"] == true, "CA Room seed %d must be 100%% contiguous, found %d regions" % [
			seed_val, r_val["region_count"]
		])
	print("  [OK] Test 2: 30 randomized CA rooms all produced 100% single-component contiguous floor")

	# Test 3: Pre-Entrance validation in DungeonPipeline with all 4 presets
	var pipeline := _DungeonPipelineScript.new()

	var presets: Array[String] = [
		"res://resources/configs/hybrid_dungeon.tres",
		"res://resources/configs/cave_dungeon.tres",
		"res://resources/configs/castle_dungeon.tres",
		"res://resources/configs/dungeon_128.tres"
	]

	for preset_path in presets:
		var cfg: DungeonConfig = load(preset_path).duplicate()
		cfg.use_fixed_seed = false

		for attempt_seed in [101, 202, 303]:
			cfg.seed = attempt_seed
			var res: DungeonResult = pipeline.call("generate", cfg, 5, true)
			assert(res != null, "Generation must succeed for preset '%s' with seed %d" % [preset_path, attempt_seed])

			# 3.1 Verificar que cada habitación sea internamente contigua
			for r in res.rooms:
				var r_check = _StructuralValidatorScript.validate_room_internal_connectivity(res.grid, r)
				assert(r_check["is_valid"], "Room %d in preset %s must be internally contiguous" % [r.id, preset_path])

			# 3.2 Verificar que el 100% de las celdas transitables del mapa estén conectadas
			var global_ok := flood_fill.verify_100_percent_walkable_connected(res.grid)
			assert(global_ok, "Global dungeon for preset %s must have 0 isolated islands" % preset_path)

		print("  [OK] Test 3: Preset '%s' passed all per-room and global 100%% connectivity checks" % preset_path.get_file())

	print("[PASS] test_room_internal_connectivity completed successfully with 100% assertions passing!")
	quit(0)
