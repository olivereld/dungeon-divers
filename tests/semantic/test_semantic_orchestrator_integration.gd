class_name TestSemanticOrchestratorIntegration
extends SceneTree

const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_semantic_orchestrator_integration ---")

	var pipeline = _DungeonPipelineScript.new()
	var orchestrator = _SemanticOrchestratorScript.new()

	var presets := [
		"res://resources/configs/cave_dungeon.tres",
		"res://resources/configs/castle_dungeon.tres",
		"res://resources/configs/hybrid_dungeon.tres",
		"res://resources/configs/dungeon_128.tres"
	]

	# Test 1: Ejecución End-to-End sobre los 4 presets
	for preset_path in presets:
		var cfg: DungeonConfig = load(preset_path).duplicate()
		cfg.seed = 12345
		cfg.use_fixed_seed = true

		var d_result: DungeonResult = pipeline.generate(cfg)
		assert(d_result != null, "Pipeline generation must succeed for %s" % preset_path)
		assert(d_result.grid != null, "DungeonResult grid must exist")

		# Snapshot del grid antes de Fase 7 para verificar 0 mutaciones
		var grid_snapshot_before: Dictionary = _take_grid_snapshot(d_result.grid)

		var sem_result = orchestrator.generate_semantics(d_result, cfg)
		assert(sem_result != null, "SemanticOrchestrator must return a DungeonSemanticResult")

		# Invariante 1: CERO mutaciones en CellGrid
		var grid_snapshot_after: Dictionary = _take_grid_snapshot(d_result.grid)
		assert(_compare_grid_snapshots(grid_snapshot_before, grid_snapshot_after),
			"CellGrid MUST remain 100%% unmodified during Phase 7 for %s" % preset_path)

		# Invariante 2: Integridad de resultado semántico
		assert(sem_result.is_committed == true, "Result must be committed and immutable")
		assert(sem_result.start_room_id >= 0, "start_room_id must be valid")
		assert(sem_result.boss_room_id >= 0, "boss_room_id must be valid")
		assert(not sem_result.critical_path_rooms.is_empty(), "critical_path_rooms must not be empty")
		assert(not sem_result.depth_map.is_empty(), "depth_map must not be empty")
		assert(not sem_result.objectives.is_empty(), "objectives must contain at least SPAWN and BOSS")

		# Invariante 3: 100% de las generaciones aceptadas son resolubles
		if sem_result.gameplay_valid:
			assert(sem_result.gameplay_diagnostics["is_resolvable"] == true,
				"Accepted generation must be 100%% resolvable")
			assert(sem_result.gameplay_diagnostics["unreachable_mandatory_objectives"].is_empty(),
				"All mandatory objectives must be reached")

		# Invariante 4: seed_trace ordenado
		assert(not sem_result.seed_trace.is_empty(), "seed_trace must record stages")
		assert(sem_result.seed_trace[0]["stage"] == "start_boss", "First stage in trace must be start_boss")

		print("  [OK] Preset verified: %s (Rooms: %d, Keys: %d, Locks: %d, Valid: %s)" % [
			cfg.dungeon_id, sem_result.rooms.size(), sem_result.keys.size(), sem_result.locks.size(), str(sem_result.gameplay_valid)
		])

	# Test 2: Determinismo semántico absoluto
	var cfg_det: DungeonConfig = load("res://resources/configs/hybrid_dungeon.tres").duplicate()
	cfg_det.seed = 777888
	cfg_det.use_fixed_seed = true

	var d1 = pipeline.generate(cfg_det)
	var s1 = orchestrator.generate_semantics(d1, cfg_det)

	var d2 = pipeline.generate(cfg_det)
	var s2 = orchestrator.generate_semantics(d2, cfg_det)

	assert(s1.start_room_id == s2.start_room_id, "start_room_id must match deterministically")
	assert(s1.boss_room_id == s2.boss_room_id, "boss_room_id must match deterministically")
	assert(s1.critical_path_rooms == s2.critical_path_rooms, "critical_path_rooms must match deterministically")
	assert(s1.critical_path_connections == s2.critical_path_connections, "critical_path_connections must match deterministically")
	assert(s1.mandatory_connections == s2.mandatory_connections, "mandatory_connections must match deterministically")
	assert(s1.keys.size() == s2.keys.size(), "Keys count must match deterministically")
	assert(s1.locks.size() == s2.locks.size(), "Locks count must match deterministically")
	assert(s1.objectives.size() == s2.objectives.size(), "Objectives count must match deterministically")
	print("  [OK] Test 2: Complete deterministic reproducibility across multiple runs verified")

	print("[PASS] test_semantic_orchestrator_integration completed successfully with 100% assertions passing!")
	quit(0)

func _take_grid_snapshot(grid: CellGrid) -> Dictionary:
	var snap: Dictionary = {}
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			snap[p] = grid.get_cell(p)
	return snap

func _compare_grid_snapshots(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k) or a[k] != b[k]:
			return false
	return true
