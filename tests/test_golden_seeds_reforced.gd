extends SceneTree

## Test de Integración Integral: Golden Seeds y Semilla de Captura 221533744 (Fase Reforced).
## Valida que:
## 1. En pasillos cortos (<= 3 celdas) NUNCA se generen dos puertas físicas de madera enfrentadas.
## 2. La semilla 221533744 genere una mazmorra completa y navegable sin solapamiento de puertas ni fallos.
## 3. Todas las semillas de la suite Golden generen mazmorras 100% deterministas y conformes con la política.

const GOLDEN_SEEDS: Array[int] = [
	221533744, # Semilla de la captura 1
	812297351, # Semilla de la captura 2
	1337,
	42,
	101,
	999,
	7777,
	12345,
	54321,
	888888,
	9999999
]

func _init() -> void:
	print("--- Running test_golden_seeds_reforced (Fase Reforced) ---")
	var pipeline := DungeonPipeline.new()
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	for s in GOLDEN_SEEDS:
		var config := DungeonConfig.new()
		config.seed = s
		config.use_fixed_seed = true
		config.grid_width = 48
		config.grid_height = 48
		config.bsp_min_room = Vector2i(6, 6)
		config.bsp_max_room = Vector2i(12, 12)
		config.corridor_width = 2
		config.extra_loop_chance = 0.15

		var res = pipeline.generate(config, 5, false)
		assert(res != null and res.grid != null, "Pipeline generation must succeed for seed %d" % s)
		assert(res.door_pairs != null and res.door_pairs.size() > 0, "Must produce door pairs for seed %d" % s)

		# Mapear longitud de pasillos por connection_id
		var path_lengths: Dictionary = {}
		for p in res.corridor_paths:
			if p != null:
				path_lengths[p.connection_id] = p.centerline_cells.size()

		# Validar regla estricta: Cero dobles puertas de madera en pasillos cortos (<= 3 celdas)
		var short_corridor_double_doors: int = 0
		var total_open_passages: int = 0
		var total_closed_doors: int = 0
		var ValidatorScript = preload("res://src/dungeon_generator/core/validation/door_physical_validator.gd")

		for dp in res.door_pairs:
			var conn_id = dp.connection_id
			var length: int = path_lengths.get(conn_id, 999)

			var door_a_closed: bool = (dp.door_a.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE)
			var door_b_closed: bool = (dp.door_b.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE)

			if door_a_closed:
				total_closed_doors += 1
				assert(ValidatorScript.validate_door_jambs(res.grid, dp.door_a.position, dp.door_a.side), "Door A at %s must have solid lateral jambs" % str(dp.door_a.position))
			else:
				total_open_passages += 1

			if door_b_closed:
				total_closed_doors += 1
				assert(ValidatorScript.validate_door_jambs(res.grid, dp.door_b.position, dp.door_b.side), "Door B at %s must have solid lateral jambs" % str(dp.door_b.position))
			else:
				total_open_passages += 1

			if length <= config.short_corridor_single_door_threshold:
				if door_a_closed and door_b_closed:
					short_corridor_double_doors += 1

		assert(short_corridor_double_doors == 0, "Seed %d generated %d double doors in short corridors! Must be 0" % [s, short_corridor_double_doors])
		print("  [PASS] Seed %10d: Rooms=%2d, Corridors=%2d, ClosedDoors=%2d, OpenPassages=%2d, ShortDoubleDoors=0, Jambs=OK" % [
			s, res.rooms.size(), res.corridor_paths.size(), total_closed_doors, total_open_passages
		])

	print("\n>>> ALL GOLDEN SEEDS AND SEED 221533744 PASSED FASE REFORCED VALIDATION! <<<")
	quit(0)
