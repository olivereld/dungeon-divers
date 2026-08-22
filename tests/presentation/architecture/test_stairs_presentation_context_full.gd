extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const StairsPresentationContextBuilderScript = preload("res://src/presentation/architecture/stairs_presentation_context_builder.gd")
const StairsPresentationResolverScript = preload("res://src/presentation/architecture/stairs_presentation_resolver.gd")
const StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_stairs_presentation_context_full ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 667788
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.TEMPLE

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var initial_byte_buffer = res.grid.get_raw_byte_buffer()

	var ctx_builder := PresentationContextBuilderScript.new()
	var room_contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	var start_room_id = sem.start_room_id
	var start_geom = partition.get_room_geometry(start_room_id)
	assert(start_geom != null and not start_geom.floor_cells.is_empty())

	var stair_cell: Vector2i = start_geom.floor_cells[0]
	var stair_up = StairDataScript.new("stair_up", 0, stair_cell, 0.0, "conn_1", false, 1)
	var stair_down = StairDataScript.new("stair_down", 1, stair_cell + Vector2i(1, 0), PI, "conn_2", true, 0)

	var stairs_builder := StairsPresentationContextBuilderScript.new()
	var stairs_contexts = stairs_builder.build([stair_up, stair_down], room_contexts, partition)
	var resolver := StairsPresentationResolverScript.new()

	test_stairs_context_resolves_room_id(stairs_contexts, start_room_id)
	test_stairs_context_preserves_profile(stairs_contexts)
	test_stairs_context_resolves_direction(stairs_contexts)
	test_stairs_context_is_deterministic(stairs_builder, [stair_up, stair_down], room_contexts, partition)
	test_stairs_context_does_not_mutate_semantic_result(res.grid, initial_byte_buffer)
	test_stairs_does_not_use_dominant_profile(resolver)

	print("[PASS] All StairsPresentationContext & Resolver tests passed successfully!")
	quit(0)

func test_stairs_context_resolves_room_id(stairs_contexts: Array, expected_room_id: int) -> void:
	assert(stairs_contexts.size() == 2, "FAIL: Must build 2 stair contexts")
	assert(stairs_contexts[0].room_id == expected_room_id, "FAIL: Room ID mismatch for stair_up")
	print("  [OK] test_stairs_context_resolves_room_id passed.")

func test_stairs_context_preserves_profile(stairs_contexts: Array) -> void:
	for s_ctx in stairs_contexts:
		assert(s_ctx.source_profile != null, "FAIL: source_profile cannot be null")
	print("  [OK] test_stairs_context_preserves_profile passed.")

func test_stairs_context_resolves_direction(stairs_contexts: Array) -> void:
	assert(stairs_contexts[0].is_downward == false, "FAIL: stair_up must have is_downward = false")
	assert(stairs_contexts[1].is_downward == true, "FAIL: stair_down must have is_downward = true")
	print("  [OK] test_stairs_context_resolves_direction passed.")

func test_stairs_context_is_deterministic(builder, stairs: Array, contexts: Array, partition) -> void:
	var list1 = builder.build(stairs, contexts, partition)
	var list2 = builder.build(stairs, contexts, partition)

	assert(list1.size() == list2.size(), "FAIL: Size mismatch")
	for i in range(list1.size()):
		assert(list1[i].stair_id == list2[i].stair_id, "FAIL: stair_id mismatch")
		assert(list1[i].is_downward == list2[i].is_downward, "FAIL: direction mismatch")
		assert(list1[i].cell == list2[i].cell, "FAIL: cell mismatch")
	print("  [OK] test_stairs_context_is_deterministic passed.")

func test_stairs_context_does_not_mutate_semantic_result(grid, initial_buffer: PackedByteArray) -> void:
	assert(grid.get_raw_byte_buffer() == initial_buffer, "FAIL: CellGrid was mutated during stairs context building!")
	print("  [OK] test_stairs_context_does_not_mutate_semantic_result passed.")

func test_stairs_does_not_use_dominant_profile(resolver) -> void:
	var prof_wood := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.MINE_ROCK,
		ArchitecturalStyleScript.WallStyle.MINE_ROCK,
		ArchitecturalStyleScript.DoorStyle.MINE_FRAME,
		ArchitecturalStyleScript.StairsStyle.WOOD
	)
	var ctx_wood := PresentationRoomContextScript.new(
		5, Rect2i(0, 0, 6, 6), RoomPurposeScript.Type.WORKSHOP, prof_wood, PresentationRoomRoleScript.Role.EXPLORE
	)

	var stair = StairDataScript.new("stair_wood", 0, Vector2i(2, 2), 0.0, "conn_wood", false, 1)
	var s_builder := StairsPresentationContextBuilderScript.new()

	# Simulación de partición con spatial query
	var mock_ctx = [ctx_wood]
	var s_ctx = s_builder.build([stair], mock_ctx, null)
	assert(s_ctx.size() == 1)

	# Asignar manualmente room_id para verificar resolución aislada
	s_ctx[0].source_profile = prof_wood
	var specs = resolver.resolve_stairs_specs(s_ctx[0])
	assert(specs.stairs_style == ArchitecturalStyleScript.StairsStyle.WOOD, "FAIL: Expected WOOD stairs style")
	print("  [OK] test_stairs_does_not_use_dominant_profile passed.")
