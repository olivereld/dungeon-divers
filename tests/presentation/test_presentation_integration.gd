class_name TestPresentationIntegration
extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_presentation_integration ---")

	var pipeline = _DungeonPipelineScript.new()
	var semantic_orchestrator = _SemanticOrchestratorScript.new()
	var presentation_builder = _DungeonPresentationBuilderScript.new()

	var presets := [
		"res://resources/configs/cave_dungeon.tres",
		"res://resources/configs/castle_dungeon.tres",
		"res://resources/configs/hybrid_dungeon.tres",
		"res://resources/configs/dungeon_128.tres"
	]

	var parent_node := Node3D.new()

	# Test 1: Ejecución End-to-End sobre los 4 presets
	for preset_path in presets:
		var cfg: DungeonConfig = load(preset_path).duplicate()
		cfg.seed = 12345
		cfg.use_fixed_seed = true

		var d_result: DungeonResult = pipeline.generate(cfg)
		assert(d_result != null, "Physical generation must succeed for %s" % preset_path)

		var sem_result: DungeonSemanticResult = semantic_orchestrator.generate_semantics(d_result, cfg)
		assert(sem_result != null and sem_result.gameplay_valid, "Semantic validation must succeed for %s" % preset_path)

		# Snapshot previo del CellGrid
		var grid_snapshot_before: Dictionary = _take_snapshot(sem_result.grid)

		var biome: BiomeProfile = cfg.biome_profile if cfg.biome_profile != null else _BiomeProfileScript.new()
		var pres_res = presentation_builder.build_presentation(
			sem_result, parent_node, biome, cfg, null, true
		)

		# Invariante 1: CERO mutaciones en CellGrid
		var grid_snapshot_after: Dictionary = _take_snapshot(sem_result.grid)
		assert(_compare_snapshots(grid_snapshot_before, grid_snapshot_after),
			"CellGrid MUST remain 100%% unmodified during Phase 8 for %s" % preset_path)

		# Invariante 2: Integridad del resultado de presentación
		assert(pres_res.success == true, "Presentation build must succeed for %s" % preset_path)
		assert(pres_res.staging_committed == true, "Staging must be committed")
		assert(pres_res.presentation_root != null, "presentation_root must exist")
		assert(pres_res.total_tiles_rendered > 0, "total_tiles_rendered must be > 0")

		# Invariante 3: Correspondencia Lógica -> Visual de Entidades
		var pres_root: Node3D = pres_res.presentation_root
		var entities_node := pres_root.get_node("Entities")
		assert(entities_node != null, "Entities root node must exist")

		var keys_node := entities_node.get_node("Keys")
		assert(keys_node.get_child_count() == sem_result.keys.size(),
			"Spawned keys count must match semantic keys count (%d == %d)" % [keys_node.get_child_count(), sem_result.keys.size()])

		var locks_node := entities_node.get_node("Locks")
		assert(locks_node.get_child_count() == sem_result.locks.size(),
			"Spawned locks count must match semantic locks count (%d == %d)" % [locks_node.get_child_count(), sem_result.locks.size()])

		var objectives_node := entities_node.get_node("Objectives")
		assert(objectives_node.get_child_count() == sem_result.objectives.size(),
			"Spawned objectives count must match semantic objectives count (%d == %d)" % [objectives_node.get_child_count(), sem_result.objectives.size()])

		print("  [OK] Preset verified: %s (Tiles: %d, Keys: %d, Locks: %d, Objectives: %d)" % [
			cfg.dungeon_id, pres_res.total_tiles_rendered,
			sem_result.keys.size(), sem_result.locks.size(), sem_result.objectives.size()
		])

		# Limpiar para el siguiente preset
		pres_root.free()

	# Test 2: Determinismo absoluto en datos y transformaciones
	var cfg_det: DungeonConfig = load("res://resources/configs/hybrid_dungeon.tres").duplicate()
	cfg_det.seed = 987654
	cfg_det.use_fixed_seed = true

	var d1 = pipeline.generate(cfg_det)
	var s1 = semantic_orchestrator.generate_semantics(d1, cfg_det)
	var b1 = cfg_det.biome_profile if cfg_det.biome_profile != null else _BiomeProfileScript.new()
	var p1 = presentation_builder.build_presentation(s1, parent_node, b1, cfg_det, null, true)

	var d2 = pipeline.generate(cfg_det)
	var s2 = semantic_orchestrator.generate_semantics(d2, cfg_det)
	var b2 = cfg_det.biome_profile if cfg_det.biome_profile != null else _BiomeProfileScript.new()
	var p2 = presentation_builder.build_presentation(s2, parent_node, b2, cfg_det, null, true)

	assert(p1.total_tiles_rendered == p2.total_tiles_rendered, "Rendered tile count must be identical")
	assert(p1.spawned_entities.size() == p2.spawned_entities.size(), "Spawned entities count must be identical")

	for i in range(p1.spawned_entities.size()):
		var n1: Node3D = p1.spawned_entities[i] as Node3D
		var n2: Node3D = p2.spawned_entities[i] as Node3D
		assert(n1.position == n2.position, "Entity %d position must match exactly across deterministic runs" % i)
		assert(n1.rotation == n2.rotation, "Entity %d rotation must match exactly across deterministic runs" % i)

	p1.presentation_root.free()
	p2.presentation_root.free()
	parent_node.free()

	print("  [OK] Test 2: Deterministic 3D presentation verified across identical seeds")

	print("[PASS] test_presentation_integration completed successfully with 100% assertions passing!")
	quit(0)

func _take_snapshot(grid: CellGrid) -> Dictionary:
	var s: Dictionary = {}
	for y in range(grid.height):
		for x in range(grid.width):
			var p := Vector2i(x, y)
			s[p] = grid.get_cell(p)
	return s

func _compare_snapshots(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k) or a[k] != b[k]:
			return false
	return true
