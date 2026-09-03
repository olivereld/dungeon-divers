class_name TestDungeonQualityMetrics
extends SceneTree

## Validación formal de Bloque D: Calidad y Métricas de Mazmorras Generadas.
## Evalúa el contrato DungeonQualityReport, los cálculos D1, D2, D3 y la agregación D4.

const _DungeonQualityReportScript = preload("res://src/dungeon_generator/core/quality/data/dungeon_quality_report.gd")
const _DungeonQualityAnalyzerScript = preload("res://src/dungeon_generator/core/quality/dungeon_quality_analyzer.gd")
const _DungeonQualityAggregatorScript = preload("res://src/dungeon_generator/core/quality/dungeon_quality_aggregator.gd")

const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")

func _init() -> void:
	print("--- Running test_dungeon_quality_metrics ---")

	test_report_contract()
	test_analyzer_synthetic_and_key_lock_spacing()
	test_aggregator_rates()

	print("[PASS] test_dungeon_quality_metrics passed with 100% assertions successful!")
	quit(0)

func test_report_contract() -> void:
	var report = _DungeonQualityReportScript.new()
	report.set_seed_val("999")
	report.set_validity(true, true)
	report.set_room_metrics({
		"room_fill_ratio": 0.20,
		"nearest_neighbor_cv": 0.12,
		"radial_variance": 50.0,
		"edge_stretch": 1.15
	})
	report.set_corridor_metrics({
		"length_stats": { "min": 3, "max": 12, "mean": 7.5, "median": 7 },
		"length_variance": 6.2,
		"short_corridor_rate": 0.10,
		"turn_count_stats": { "min": 0, "max": 2, "mean": 1.0, "total": 4 },
		"longest_straight_run": 6
	})
	report.set_gameplay_metrics({
		"critical_path_length": 25.0,
		"critical_path_room_count": 4,
		"objective_spacing": 1.5,
		"key_lock_spacing": 12.0,
		"start_boss_distance": 22.0,
		"start_goal_distance": 0.0,
		"branch_count": 1,
		"optional_branch_depth": 1.0
	})
	report.seal()

	assert(report.is_sealed() == true, "Report must be sealed")
	var dict: Dictionary = report.to_dict()
	assert(dict["seed"] == "999", "Seed must be string 999")
	assert(dict["semantic_valid"] == true, "semantic_valid must be true")
	assert(dict["gameplay_valid"] == true, "gameplay_valid must be true")
	assert(dict["room_metrics"]["room_fill_ratio"] == 0.20, "room_metrics must match")
	assert(dict["corridor_metrics"]["longest_straight_run"] == 6, "corridor_metrics must match")
	assert(dict["gameplay_metrics"]["critical_path_room_count"] == 4, "gameplay_metrics must match")
	print("  [OK] Test 1: Contract, structure and immutability verified.")

func test_analyzer_synthetic_and_key_lock_spacing() -> void:
	var analyzer = _DungeonQualityAnalyzerScript.new()

	# 4 rooms
	var r0 := _RoomDataScript.new(0, Rect2i(0, 0, 4, 4), &"start")
	var r1 := _RoomDataScript.new(1, Rect2i(10, 0, 4, 4), &"treasure")
	var r2 := _RoomDataScript.new(2, Rect2i(20, 0, 4, 4), &"combat")
	var r3 := _RoomDataScript.new(3, Rect2i(30, 0, 4, 4), &"boss")
	var rooms: Array = [r0, r1, r2, r3]

	var c0 := _RoomConnectionScript.new(0, 0, 1)
	var c1 := _RoomConnectionScript.new(1, 1, 2)
	var c2 := _RoomConnectionScript.new(2, 2, 3)
	var conns: Array = [c0, c1, c2]

	var cp0 := _CorridorPathScript.new(0, 0, 1, [Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2), Vector2i(6,2), Vector2i(7,2), Vector2i(8,2), Vector2i(9,2), Vector2i(10,2), Vector2i(11,2)], [], 10.0, 0, 0, 10)
	var cps: Array = [cp0]

	# D1 Rooms
	var room_m = analyzer.compute_room_metrics(rooms, conns, cps, Vector2i(40, 10))
	assert(room_m["room_fill_ratio"] > 0.0, "room_fill_ratio must be positive")
	assert(room_m["nearest_neighbor_cv"] >= 0.0, "nearest_neighbor_cv must be >= 0")
	assert(room_m["radial_variance"] >= 0.0, "radial_variance must be >= 0")
	assert(room_m["edge_stretch"] > 0.0, "edge_stretch must be positive")

	# D2 Corridors
	var corr_m = analyzer.compute_corridor_metrics(cps)
	assert(corr_m["length_stats"]["mean"] == 10.0, "Mean length must be 10.0")
	assert(corr_m["longest_straight_run"] == 10, "longest_straight_run must be 10")

	# D3 Gameplay con múltiples pares de llave/cerradura
	var k1 := _KeyDataScript.new(100, &"k1", 1, Vector2i(10, 0), 1)
	var k2 := _KeyDataScript.new(200, &"k2", 2, Vector2i(20, 0), 2)
	var l1 := _LockDataScript.new(1, 0, 0, 1, 100)
	var l2 := _LockDataScript.new(2, 2, 2, 3, 200)

	var sem_res := _DungeonSemanticResultScript.new()
	sem_res.start_room_id = 0
	sem_res.boss_room_id = 3
	sem_res.critical_path_rooms = [0, 1, 2, 3]
	sem_res.depth_map = { 0: 0, 1: 1, 2: 2, 3: 3 }
	sem_res.keys = [k1, k2]
	sem_res.locks = [l1, l2]
	sem_res.objectives = []
	sem_res.mark_committed()

	var gp_m = analyzer.compute_gameplay_metrics(rooms, conns, cps, sem_res)
	assert(gp_m["key_lock_spacing"] > 0.0, "key_lock_spacing must be computed across multiple pairs")
	assert(gp_m["critical_path_room_count"] == 4, "critical_path_room_count must be 4")
	assert(gp_m["start_boss_distance"] > 0.0, "start_boss_distance must be positive")
	print("  [OK] Test 2: Synthetic D1, D2 and multiple key/lock spacing verified.")

func test_aggregator_rates() -> void:
	var aggregator = _DungeonQualityAggregatorScript.new()

	var r1 := _DungeonQualityReportScript.new()
	r1.set_seed_val("1")
	r1.set_validity(true, true)
	r1.seal()

	var r2 := _DungeonQualityReportScript.new()
	r2.set_seed_val("2")
	r2.set_validity(true, false) # Failed gameplay
	r2.seal()

	var summary = aggregator.aggregate_reports([r1, r2])
	assert(summary["total_evaluated"] == 2, "total_evaluated must be 2")
	assert(summary["semantic_valid_count"] == 2, "semantic_valid_count must be 2")
	assert(summary["semantic_valid_rate"] == 1.0, "semantic_valid_rate must be 1.0")
	assert(summary["gameplay_valid_count"] == 1, "gameplay_valid_count must be 1")
	assert(summary["gameplay_valid_rate"] == 0.5, "gameplay_valid_rate must be 0.5")
	assert(summary["fully_valid_count"] == 1, "fully_valid_count must be 1")
	print("  [OK] Test 3: Aggregator rates (D4) verified.")
