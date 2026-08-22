extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const DoorPresentationContextBuilderScript = preload("res://src/presentation/architecture/door_presentation_context_builder.gd")
const StairsPresentationContextBuilderScript = preload("res://src/presentation/architecture/stairs_presentation_context_builder.gd")
const DungeonDoorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
const DungeonStairSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
const StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_relational_presentation_integration ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 123456
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var room_contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	var door_ctx_builder := DoorPresentationContextBuilderScript.new()
	var door_contexts = door_ctx_builder.build(sem.door_pairs, room_contexts)

	var stairs_builder := StairsPresentationContextBuilderScript.new()
	var stairs_contexts = stairs_builder.build(sem.stairs if "stairs" in sem and sem.stairs != null else [], room_contexts, partition)

	var biome := BiomeProfileScript.new()

	test_door_context_reaches_spawner(sem, door_contexts, partition, biome, cfg)
	test_stairs_source_and_target_resolution(room_contexts, partition)
	test_full_architectural_presentation_reaches_3d(sem, biome, cfg)

	print("[PASS] test_relational_presentation_integration completed successfully!")
	quit(0)

func test_door_context_reaches_spawner(sem, door_contexts: Array, partition, biome, config) -> void:
	var spawner := DungeonDoorSpawnerScript.new()
	var staging := Node3D.new()
	root.add_child(staging)

	var door_manifests = DoorManifestFactoryScript.create_door_manifests(sem.door_pairs)
	var spawn_res = spawner.spawn_doors(
		door_manifests, staging, biome, config.cell_size, config.wall_height,
		config.seed, sem.grid, partition, door_contexts
	)

	assert(not spawn_res.spawned_doors.is_empty(), "FAIL: Doors must be materialized in staging")
	for door_node in spawn_res.spawned_doors:
		assert(door_node.has_meta("door_context"), "FAIL: Door node must retain its DoorPresentationContext")
		assert(door_node.has_meta("resolved_style"), "FAIL: Door node must have resolved_style metadata")

	staging.queue_free()
	print("  [OK] test_door_context_reaches_spawner passed.")

func test_stairs_source_and_target_resolution(room_contexts: Array, partition) -> void:
	var prof_src := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
		ArchitecturalStyleScript.StairsStyle.STONE
	)
	var prof_dst := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
		ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
		ArchitecturalStyleScript.StairsStyle.WOOD
	)

	var ctx_src := PresentationRoomContextScript.new(0, Rect2i(0, 0, 5, 5), RoomPurposeScript.Type.CRYPT, prof_src, PresentationRoomRoleScript.Role.START)
	var ctx_dst := PresentationRoomContextScript.new(1, Rect2i(10, 0, 5, 5), RoomPurposeScript.Type.SANCTUM, prof_dst, PresentationRoomRoleScript.Role.BOSS)

	var stair = StairDataScript.new("stair_conn_1", 0, Vector2i(2, 2), 0.0, "v_conn_1", true, 1)
	var s_builder := StairsPresentationContextBuilderScript.new()

	var multi_level_target_contexts: Dictionary = {
		1: [ctx_dst]
	}

	var s_contexts = s_builder.build([stair], [ctx_src], partition, multi_level_target_contexts)
	assert(s_contexts.size() == 1, "FAIL: Stairs context must be generated")
	assert(s_contexts[0].source_profile != null or s_contexts[0].room_id == -1)

	var s_spawner := DungeonStairSpawnerScript.new()
	var staging := Node3D.new()
	root.add_child(staging)

	var biome := BiomeProfileScript.new()
	var stair_res = s_spawner.spawn_stairs([stair], staging, biome, 2.0, 6.0, 1337, partition, s_contexts)
	assert(stair_res.spawned_stairs.size() == 1, "FAIL: Stair must be spawned")
	var st_node = stair_res.spawned_stairs[0]
	assert(st_node.has_meta("stairs_context"), "FAIL: Stair node must retain its StairsPresentationContext")
	assert(st_node.has_meta("resolved_style"), "FAIL: Stair node must have resolved_style metadata")

	staging.queue_free()
	print("  [OK] test_stairs_source_and_target_resolution passed.")

func test_full_architectural_presentation_reaches_3d(sem, biome, config) -> void:
	var pres_builder := DungeonPresentationBuilderScript.new()
	var parent_node := Node3D.new()
	root.add_child(parent_node)

	var pres_res = pres_builder.build_presentation(sem, parent_node, biome, config)
	assert(pres_res != null and not pres_res.has_blocking_errors(), "FAIL: Presentation build failed")
	assert(pres_res.total_tiles_rendered > 0, "FAIL: Presentation rendered 0 tiles")

	parent_node.queue_free()
	print("  [OK] test_full_architectural_presentation_reaches_3d passed.")
