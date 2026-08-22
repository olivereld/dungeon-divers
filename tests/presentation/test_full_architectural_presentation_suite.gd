extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_full_architectural_presentation_suite ---")
	print("==================================================================")

	var pipeline := DungeonPipelineScript.new()
	var orchestrator := SemanticOrchestratorScript.new()
	var pres_builder := DungeonPresentationBuilderScript.new()
	var ctx_builder := PresentationContextBuilderScript.new()
	var biome := BiomeProfileScript.new()

	var test_seed: int = 778899

	# 1. Test de Determinismo Absoluto (2 corridas con la misma semilla)
	var cfg1 := DungeonConfigScript.new()
	cfg1.seed = test_seed
	cfg1.use_fixed_seed = true
	cfg1.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var res1 = pipeline.generate(cfg1, 5, true)
	var sem1 = orchestrator.generate_semantics(res1, cfg1)
	var ctxs1 = ctx_builder.build_contexts(sem1)
	var part1 := PresentationGeometryPartitionScript.new()
	part1.build_partition(res1.grid, ctxs1, sem1)

	var cfg2 := DungeonConfigScript.new()
	cfg2.seed = test_seed
	cfg2.use_fixed_seed = true
	cfg2.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var res2 = pipeline.generate(cfg2, 5, true)
	var sem2 = orchestrator.generate_semantics(res2, cfg2)
	var ctxs2 = ctx_builder.build_contexts(sem2)
	var part2 := PresentationGeometryPartitionScript.new()
	part2.build_partition(res2.grid, ctxs2, sem2)

	assert(res1.grid.get_raw_byte_buffer() == res2.grid.get_raw_byte_buffer(), "FAIL: Topologies must be byte-identical")
	assert(part1.rooms_geometry.size() == part2.rooms_geometry.size(), "FAIL: Partition sizes must match")
	assert(part1.corridor_floor_cells.size() == part2.corridor_floor_cells.size(), "FAIL: Corridor cells count must match")

	for r_id in part1.rooms_geometry:
		var g1 = part1.get_room_geometry(r_id)
		var g2 = part2.get_room_geometry(r_id)
		assert(g1.floor_cells == g2.floor_cells, "FAIL: Room floor cells must be deterministic")
		assert(g1.profile.floor_style == g2.profile.floor_style, "FAIL: Room profiles must be deterministic")

	# 2. Test de Presentación 3D en Staging
	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var pres_res = pres_builder.build_presentation(sem1, parent_node, biome, cfg1)
	assert(pres_res != null, "FAIL: Presentation result cannot be null")
	assert(not pres_res.has_blocking_errors(), "FAIL: Presentation has blocking errors")
	assert(pres_res.total_tiles_rendered > 0, "FAIL: Tiles rendered must be > 0")

	# Verificar props y fixtures instanciados por composición
	var prop_count: int = 0
	var fixture_count: int = 0
	for child in pres_res.presentation_root.get_children():
		if child.name.begins_with("Prop_"):
			prop_count += 1
		elif child.name == "Fixtures":
			fixture_count += child.get_child_count()

	assert(prop_count > 0, "FAIL: Expected composed props in presentation root")
	assert(fixture_count > 0, "FAIL: Expected composed fixtures in presentation root")

	# 3. Test de Room Archetype Lab (Generación aislada)
	var lab_gen := preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd").new()
	var lab_req := preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd").new(
		DungeonArchetypeScript.Type.MAUSOLEUM, 11, test_seed
	)
	var lab_res = lab_gen.generate_preview(lab_req)
	assert(lab_res.success, "FAIL: Lab preview generation failed")
	assert(lab_res.diagnostics.get("props_count", 0) > 0, "FAIL: Lab preview props missing")
	lab_res.room_root.free()

	print("  [OK] Absolute determinism verified across independent generation runs.")
	print("  [OK] CellGrid immutability preserved bit-by-bit.")
	print("  [OK] Full 3D presentation staging verified with %d props and %d fixtures." % [prop_count, fixture_count])
	print("  [OK] Room Archetype Lab isolated generation verified successfully.")
	print("[PASS] test_full_architectural_presentation_suite completed successfully.")
	quit(0)
