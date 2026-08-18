extends SceneTree

## Test de Verificación de Semillas Doradas y Calidad Estética Visual (Fase 10 - Plan Refined).
## Evalúa 10 semillas doradas distribuidas en los 3 arquetipos (BSP, CellularAutomata, Hybrid)
## asegurando 0 escaleras diagonales, <= 2.0 giros promedio por corredor, 100% transitabilidad y determinismo.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")

func _init() -> void:
	print("================================================================")
	print("   EJECUTANDO SUITE DE GOLDEN SEEDS & CALIDAD ESTÉTICA (TASK 10)  ")
	print("================================================================")

	var pipeline = _DungeonPipelineScript.new()
	var flood_fill = _FloodFillScript.new()

	var golden_specs: Array[Dictionary] = [
		# Arquetipo 1: BSP / Castle Keep
		{"config_path": "res://resources/configs/castle_dungeon.tres", "seed": 101, "name": "BSP_Castle_101"},
		{"config_path": "res://resources/configs/castle_dungeon.tres", "seed": 102, "name": "BSP_Castle_102"},
		{"config_path": "res://resources/configs/castle_dungeon.tres", "seed": 103, "name": "BSP_Castle_103"},

		# Arquetipo 2: Cellular Automata / Cave
		{"config_path": "res://resources/configs/cave_dungeon.tres", "seed": 201, "name": "CA_Cave_201"},
		{"config_path": "res://resources/configs/cave_dungeon.tres", "seed": 202, "name": "CA_Cave_202"},
		{"config_path": "res://resources/configs/cave_dungeon.tres", "seed": 203, "name": "CA_Cave_203"},

		# Arquetipo 3: Hybrid / Hybrid Depths
		{"config_path": "res://resources/configs/hybrid_dungeon.tres", "seed": 301, "name": "Hybrid_301"},
		{"config_path": "res://resources/configs/hybrid_dungeon.tres", "seed": 302, "name": "Hybrid_302"},
		{"config_path": "res://resources/configs/hybrid_dungeon.tres", "seed": 303, "name": "Hybrid_303"},
		{"config_path": "res://resources/configs/hybrid_dungeon.tres", "seed": 304, "name": "Hybrid_304"},
	]

	var evaluated_count: int = 0

	for spec in golden_specs:
		var cfg: DungeonConfig = load(spec["config_path"]).duplicate()
		cfg.seed = spec["seed"]
		cfg.use_fixed_seed = true

		print("\n>> Evaluando Golden Seed: %s (Seed: %d)..." % [spec["name"], spec["seed"]])

		# 1. Primera ejecución
		var res1 = pipeline.generate(cfg, 5, false)
		assert(res1 != null and res1.grid != null, "Golden seed %s must generate successfully" % spec["name"])

		# 2. Segunda ejecución para validar determinismo exacto
		var res2 = pipeline.generate(cfg, 5, false)
		assert(res2 != null, "Golden seed %s second run must succeed" % spec["name"])
		assert(res1.grid.to_debug_string() == res2.grid.to_debug_string(), "Grid ASCII must be 100%% deterministic")
		assert(res1.corridor_paths.size() == res2.corridor_paths.size(), "Corridor count must match deterministically")

		# 3. Validar transitabilidad al 100% mediante FloodFill
		var connected_100: bool = flood_fill.verify_100_percent_walkable_connected(res1.grid)
		assert(connected_100, "Golden seed %s must have 100%% connected walkable floor/corridor/door grid" % spec["name"])

		# 4. Validar métricas estéticas
		assert(res1.metadata.has("aesthetic_metrics"), "Must contain aesthetic metrics")
		var m: Dictionary = res1.metadata["aesthetic_metrics"]
		assert(m.get("staircase_corridors", -1) == 0, "Staircase corridors must be 0")
		assert(m.get("average_turns_per_corridor", 99.0) <= 2.0, "Average turns must be <= 2.0 (got %.2f)" % m.get("average_turns_per_corridor", 0.0))

		# 5. Validar puertas y extremos de corredores
		assert(res1.doors.size() > 0, "Must have doors placed")
		for dp in res1.door_pairs:
			assert(dp.door_a != null and dp.door_b != null, "DoorPair must have both doors")
			assert(res1.grid.get_cell(dp.door_a.position) == CellGrid.CellType.DOOR, "Door A must be DOOR in CellGrid")
			assert(res1.grid.get_cell(dp.door_b.position) == CellGrid.CellType.DOOR, "Door B must be DOOR in CellGrid")

		print("  [OK] %s: Rooms=%d, Paths=%d, Doors=%d, AvgTurns=%.2f, ZeroTurns=%.1f%%, 100%% Deterministic" % [
			spec["name"],
			res1.rooms.size(),
			res1.corridor_paths.size(),
			res1.doors.size(),
			m.get("average_turns_per_corridor", 0.0),
			m.get("percent_zero_turn", 0.0)
		])

		evaluated_count += 1

	assert(evaluated_count == 10, "Must evaluate all 10 golden seed specifications")
	print("\n================================================================")
	print(">>> ALL 10 GOLDEN SEEDS VERIFIED WITH ZERO AESTHETIC DRIFT! <<<")
	print("================================================================\n")
	quit(0)
