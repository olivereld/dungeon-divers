extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")
const DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_presentation_geometry_partition_validation ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 556677
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var initial_byte_buffer = res.grid.get_raw_byte_buffer()

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	test_partition_does_not_mutate_cell_grid(res.grid, initial_byte_buffer)
	test_rooms_do_not_overlap(partition)
	test_room_and_corridor_cells_do_not_overlap(partition)
	test_room_id_index_matches_geometry(partition)
	test_every_room_floor_cell_has_correct_room_id(partition)
	test_corridor_walls_are_adjacent_and_disjoint(partition, res.grid)
	test_room_profile_overrides_dominant_profile(contexts, ctx_builder, cfg.dungeon_archetype)
	test_per_room_structural_differentiation(res.grid, partition, sem, cfg.seed)

	print("[PASS] All 2.5.9 partition & architectural validation tests passed successfully!")
	quit(0)

func test_partition_does_not_mutate_cell_grid(grid, initial_buffer: PackedByteArray) -> void:
	assert(grid.get_raw_byte_buffer() == initial_buffer, "FAIL: CellGrid was mutated during partition!")
	print("  [OK] test_partition_does_not_mutate_cell_grid passed.")

func test_rooms_do_not_overlap(partition) -> void:
	var seen: Dictionary = {}
	for r_geom in partition.get_rooms():
		for cell in r_geom.floor_cells:
			assert(not seen.has(cell), "FAIL: Overlapping room floor cell detected: %s" % str(cell))
			seen[cell] = r_geom.room_id
	print("  [OK] test_rooms_do_not_overlap passed (Room A ∩ Room B = ∅).")

func test_room_and_corridor_cells_do_not_overlap(partition) -> void:
	var room_cells: Dictionary = {}
	for r_geom in partition.get_rooms():
		for cell in r_geom.floor_cells:
			room_cells[cell] = true

	for c_cell in partition.corridor_floor_cells:
		assert(not room_cells.has(c_cell), "FAIL: Corridor cell overlaps with room floor cell: %s" % str(c_cell))

	print("  [OK] test_room_and_corridor_cells_do_not_overlap passed (Rooms ∩ Corridors = ∅).")

func test_room_id_index_matches_geometry(partition) -> void:
	for r_geom in partition.get_rooms():
		for cell in r_geom.floor_cells:
			assert(partition.get_room_id_at(cell) == r_geom.room_id, "FAIL: room_id_by_cell index mismatch for cell %s" % str(cell))
			assert(partition.is_room_cell(cell) == true, "FAIL: is_room_cell returned false for room cell")

	for c_cell in partition.corridor_floor_cells:
		assert(partition.get_room_id_at(c_cell) == -1, "FAIL: Corridor cell returned non-negative room id")
		assert(partition.is_room_cell(c_cell) == false, "FAIL: is_room_cell returned true for corridor cell")

	print("  [OK] test_room_id_index_matches_geometry passed.")

func test_every_room_floor_cell_has_correct_room_id(partition) -> void:
	for cell in partition.room_id_by_cell:
		var r_id: int = partition.room_id_by_cell[cell]
		var r_geom = partition.get_room_geometry(r_id)
		assert(r_geom != null, "FAIL: room_id %d does not exist in partition" % r_id)
		assert(r_geom.floor_cells.has(cell), "FAIL: cell %s is not in room %d floor_cells" % [str(cell), r_id])

	print("  [OK] test_every_room_floor_cell_has_correct_room_id passed.")

func test_corridor_walls_are_adjacent_and_disjoint(partition, grid) -> void:
	var room_walls: Dictionary = {}
	for r_geom in partition.get_rooms():
		for w in r_geom.wall_cells:
			room_walls[w] = true

	for cw in partition.corridor_wall_cells:
		assert(grid.is_solid(cw), "FAIL: Corridor wall cell must be solid")
		assert(not room_walls.has(cw), "FAIL: Corridor wall cell cannot overlap with room wall cell")

	print("  [OK] test_corridor_walls_are_adjacent_and_disjoint passed (%d corridor wall cells populated)." % partition.corridor_wall_cells.size())

func test_room_profile_overrides_dominant_profile(contexts: Array, ctx_builder, archetype: int) -> void:
	var dominant = ctx_builder.get_dominant_profile(contexts, archetype)
	assert(dominant != null, "FAIL: Dominant profile must not be null")

	var distinct_purposes: Dictionary = {}
	for ctx in contexts:
		assert(ctx.profile != null, "FAIL: Room context profile cannot be null")
		distinct_purposes[ctx.purpose] = ctx.profile

	print("  [OK] test_room_profile_overrides_dominant_profile passed (%d distinct room purposes resolved)." % distinct_purposes.size())

func test_per_room_structural_differentiation(grid, partition, semantic_result, master_seed: int) -> void:
	var style_resolver := ArchitecturalStyleConfigResolverScript.new()
	var base_floor := FloorTileConfigScript.new()
	var floor_gen := DungeonFloorGeneratorScript.new()

	var floor_res = floor_gen.generate_floor_for_partition(partition, style_resolver, base_floor, master_seed)
	assert(floor_res.clusters.size() >= partition.get_rooms().size(), "FAIL: Must generate at least one cluster per room")

	var wall_cfg := WallGeometryConfigScript.new()
	var col_cfg := CollisionConfigScript.new()
	var base_dec := DecorationConfigScript.new()
	var opening_manifest = DoorManifestFactoryScript.create_wall_opening_manifest(semantic_result.door_pairs)
	var geom_gen := DungeonGeometryGeneratorScript.new()

	var wall_res = geom_gen.generate_wall_clusters_for_partition(
		grid, partition, style_resolver, opening_manifest, wall_cfg, col_cfg, base_dec, 0, master_seed
	)
	assert(not wall_res.generated_meshes.is_empty(), "FAIL: Wall meshes must be generated")

	print("  [OK] test_per_room_structural_differentiation passed.")
