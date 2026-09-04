extends SceneTree

## Smoke Test Integral: Evaluación de Generación de Mazmorra post-refactor de EntranceSolver.
## Valida sobre múltiples semillas diversas: rooms, connections, entrances, corridors, connectivity, semantics y Lab.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")

const TEST_SEEDS: Array[int] = [
	11111,
	22222,
	33333,
	445566,
	77777,
	98765
]

func _init() -> void:
	print("================================================================")
	print("   SMOKE TEST ASSESSMENT: DUNGEON GENERATION BOUNDARY REFACTOR  ")
	print("================================================================")

	var pipeline = _DungeonPipelineScript.new()
	var validator = _StructuralValidatorScript.new()

	for s in TEST_SEEDS:
		print("\n>> Evaluando Semilla Representativa: %d ..." % s)
		var cfg := DungeonConfig.new()
		cfg.seed = s
		cfg.use_fixed_seed = true

		var d_res: DungeonResult = pipeline.generate(cfg, 5, true)
		assert(d_res != null, "FAIL: Dungeon generation returned null for seed %d" % s)

		# 1. Rooms
		assert(d_res.rooms.size() >= 4, "FAIL: Seed %d must generate at least 4 rooms (got %d)" % [s, d_res.rooms.size()])
		for r in d_res.rooms:
			assert(r != null, "FAIL: Room is null")
			assert(r.rect.size.x >= 3 and r.rect.size.y >= 3, "FAIL: Room rect too small")
		print("  [OK] Rooms: %d valid rooms" % d_res.rooms.size())

		# 2. Connections & Entrances
		assert(d_res.connections.size() >= d_res.rooms.size() - 1, "FAIL: Not enough connections")
		assert(d_res.entrance_pairs.size() == d_res.connections.size(), "FAIL: EntrancePairs count (%d) != Connections count (%d)" % [
			d_res.entrance_pairs.size(), d_res.connections.size()
		])
		for ep in d_res.entrance_pairs:
			assert(ep != null, "FAIL: EntrancePair is null")
			assert(ep.is_valid(), "FAIL: EntrancePair is invalid")
			assert(d_res.grid.is_in_bounds(ep.entrance_a.position), "FAIL: Entrance A out of bounds")
			assert(d_res.grid.is_in_bounds(ep.entrance_b.position), "FAIL: Entrance B out of bounds")
		print("  [OK] Connections & Entrances: %d pairs resolved cleanly" % d_res.entrance_pairs.size())

		# 3. Corridors
		assert(d_res.corridor_paths.size() == d_res.connections.size(), "FAIL: Corridor paths (%d) != connections (%d)" % [
			d_res.corridor_paths.size(), d_res.connections.size()
		])
		for cp in d_res.corridor_paths:
			assert(cp != null, "FAIL: CorridorPath is null")
			assert(cp.centerline_cells.size() >= 1, "FAIL: CorridorPath is empty")
		print("  [OK] Corridors: %d paths carved cleanly" % d_res.corridor_paths.size())

		# 4. Structural Validation & Connectivity
		var struct_rep = validator.validate_structure(d_res.grid, d_res.rooms, d_res.connections)
		assert(struct_rep.is_valid, "FAIL: Structural validator reported errors: %s" % str(struct_rep.errors))
		assert(d_res.validation != null, "FAIL: Validation result is null")
		assert(d_res.validation.hard_valid, "FAIL: Quality gate hard constraints failed")
		print("  [OK] Structural & Quality Gate Connectivity: 100%% valid")

		# 5. Semantics & Metadata
		assert(d_res.metadata.has("aesthetic_metrics"), "FAIL: Metadata must include aesthetic metrics")
		var aes = d_res.metadata["aesthetic_metrics"]
		assert(aes["staircase_corridors"] == 0, "FAIL: Staircase corridors must be 0")
		print("  [OK] Semantics & Aesthetics: avg_turns=%.2f, staircase=0" % aes["average_turns_per_corridor"])

	# 6. Lab Integration Check
	print("\n>> Evaluando integración en Dungeon Level Lab...")
	var lab = _LabScene.instantiate()
	assert(lab != null, "FAIL: Could not instantiate lab scene")
	root.add_child(lab)
	lab._ready()

	lab.config.seed = 445566
	var lab_res = lab.controller.generate_dungeon(lab.config)
	assert(not lab_res.is_empty(), "FAIL: Lab generation failed")
	assert(lab.renderer.get_rendered_room_count() > 0, "FAIL: Lab rendered rooms is 0")
	lab.queue_free()
	print("  [OK] Lab integration: generated and rendered correctly without visual or contract crashes")

	print("\n================================================================")
	print(">>> ALL SMOKE TEST ASSESSMENT CHECKS PASSED SUCCESSFULLY (ALL GREEN) <<<")
	print("================================================================\n")
	quit(0)
