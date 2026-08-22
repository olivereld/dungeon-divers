extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const DoorPresentationContextBuilderScript = preload("res://src/presentation/architecture/door_presentation_context_builder.gd")
const DoorPresentationResolverScript = preload("res://src/presentation/architecture/door_presentation_resolver.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_door_presentation_context ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 991122
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var initial_byte_buffer = res.grid.get_raw_byte_buffer()

	var ctx_builder := PresentationContextBuilderScript.new()
	var room_contexts = ctx_builder.build_contexts(sem)

	var door_ctx_builder := DoorPresentationContextBuilderScript.new()
	var door_contexts = door_ctx_builder.build(sem.door_pairs, room_contexts)
	var resolver := DoorPresentationResolverScript.new()

	test_door_context_resolves_source_room(door_contexts)
	test_door_context_resolves_target_room(door_contexts)
	test_door_context_preserves_room_profiles(door_contexts)
	test_door_context_is_deterministic(sem.door_pairs, room_contexts)
	test_door_context_does_not_mutate_semantic_result(res.grid, initial_byte_buffer)
	test_door_does_not_use_dominant_profile()
	test_crypt_to_temple_relational_connection(resolver)

	print("[PASS] All DoorPresentationContext & Resolver tests passed successfully!")
	quit(0)

func test_door_context_resolves_source_room(door_contexts: Array) -> void:
	assert(not door_contexts.is_empty(), "FAIL: Door contexts cannot be empty")
	for d_ctx in door_contexts:
		assert(d_ctx.source_room_id >= 0, "FAIL: source_room_id must be valid")
	print("  [OK] test_door_context_resolves_source_room passed.")

func test_door_context_resolves_target_room(door_contexts: Array) -> void:
	for d_ctx in door_contexts:
		assert(d_ctx.target_room_id >= 0, "FAIL: target_room_id must be valid")
		assert(d_ctx.source_room_id != d_ctx.target_room_id, "FAIL: source and target rooms must be distinct")
	print("  [OK] test_door_context_resolves_target_room passed.")

func test_door_context_preserves_room_profiles(door_contexts: Array) -> void:
	for d_ctx in door_contexts:
		assert(d_ctx.source_profile != null, "FAIL: source_profile cannot be null")
		assert(d_ctx.target_profile != null, "FAIL: target_profile cannot be null")
	print("  [OK] test_door_context_preserves_room_profiles passed.")

func test_door_context_is_deterministic(door_pairs: Array, room_contexts: Array) -> void:
	var builder1 := DoorPresentationContextBuilderScript.new()
	var list1 = builder1.build(door_pairs, room_contexts)

	var builder2 := DoorPresentationContextBuilderScript.new()
	var list2 = builder2.build(door_pairs, room_contexts)

	assert(list1.size() == list2.size(), "FAIL: Deterministic size mismatch")
	for i in range(list1.size()):
		assert(list1[i].source_room_id == list2[i].source_room_id, "FAIL: Deterministic source room mismatch")
		assert(list1[i].target_room_id == list2[i].target_room_id, "FAIL: Deterministic target room mismatch")
		assert(list1[i].position == list2[i].position, "FAIL: Deterministic position mismatch")
	print("  [OK] test_door_context_is_deterministic passed.")

func test_door_context_does_not_mutate_semantic_result(grid, initial_buffer: PackedByteArray) -> void:
	assert(grid.get_raw_byte_buffer() == initial_buffer, "FAIL: CellGrid was mutated during door context building!")
	print("  [OK] test_door_context_does_not_mutate_semantic_result passed.")

func test_door_does_not_use_dominant_profile() -> void:
	var prof_crypt := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.HEAVY_IRON
	)
	var prof_temple := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
		ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH
	)

	var ctx_crypt := PresentationRoomContextScript.new(
		0, Rect2i(0, 0, 6, 6), RoomPurposeScript.Type.CRYPT, prof_crypt, PresentationRoomRoleScript.Role.START
	)
	var ctx_temple := PresentationRoomContextScript.new(
		1, Rect2i(10, 0, 6, 6), RoomPurposeScript.Type.SANCTUM, prof_temple, PresentationRoomRoleScript.Role.BOSS
	)

	var dp := DoorPairScript.new(
		1,
		DoorPlacementScript.new(1, 0, Vector2i(6, 3), 1),
		DoorPlacementScript.new(1, 1, Vector2i(10, 3), 3)
	)

	var builder := DoorPresentationContextBuilderScript.new()
	var res = builder.build([dp], [ctx_crypt, ctx_temple])
	assert(res.size() == 1, "FAIL: Must build exactly 1 door context")

	var door_ctx = res[0]
	assert(door_ctx.source_profile == prof_crypt, "FAIL: Source profile must match Crypt")
	assert(door_ctx.target_profile == prof_temple, "FAIL: Target profile must match Temple")
	print("  [OK] test_door_does_not_use_dominant_profile passed.")

func test_crypt_to_temple_relational_connection(resolver) -> void:
	var prof_crypt := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.HEAVY_IRON
	)
	var prof_temple := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
		ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH
	)

	var ctx_crypt := PresentationRoomContextScript.new(
		0, Rect2i(0, 0, 6, 6), RoomPurposeScript.Type.CRYPT, prof_crypt, PresentationRoomRoleScript.Role.START
	)
	var ctx_temple := PresentationRoomContextScript.new(
		1, Rect2i(10, 0, 6, 6), RoomPurposeScript.Type.SANCTUM, prof_temple, PresentationRoomRoleScript.Role.BOSS
	)

	var dp := DoorPairScript.new(
		1,
		DoorPlacementScript.new(1, 0, Vector2i(6, 3), 1),
		DoorPlacementScript.new(1, 1, Vector2i(10, 3), 3)
	)

	var builder := DoorPresentationContextBuilderScript.new()
	var res = builder.build([dp], [ctx_crypt, ctx_temple])
	var door_ctx = res[0]

	var specs = resolver.resolve_door_specs(door_ctx)
	assert(specs.door_style == ArchitecturalStyleScript.DoorStyle.HEAVY_IRON, "FAIL: Heavy Iron door style expected")
	assert(specs.source_room_id == 0)
	assert(specs.target_room_id == 1)

	print("  [OK] test_crypt_to_temple_relational_connection passed.")
