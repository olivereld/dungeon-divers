extends SceneTree

## Commit 6:
## Valida que ObjectiveData.BOSS se materializa correctamente como Node3D
## y conserva objective_id, room_id, type y posición.

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const ObjectiveData = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonEntitySpawner = preload("res://src/dungeon_generator/presentation/dungeon_entity_spawner.gd")

func _init() -> void:
	print("--- Running test_boss_entity_materialization (1000 seeds) ---")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var entity_spawner := DungeonEntitySpawner.new()

	var total_seeds: int = 1000

	for i in range(total_seeds):
		var seed_val: int = 200000 + i

		var config := DungeonConfig.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		config.boss_enabled = true

		# 1. Generar DungeonResult.
		var d_res: DungeonResult = pipeline.generate(
			config,
			DungeonPipeline.MAX_ATTEMPTS,
			true,
			false
		)

		assert(
			d_res != null,
			"Seed %d: DungeonPipeline returned null result" % seed_val
		)

		# 2. Generar capa semántica.
		var semantic_result = semantic_orchestrator.generate_semantics(
			d_res,
			config
		)

		assert(
			semantic_result != null,
			"Seed %d: SemanticResult is null" % seed_val
		)

		# 3. Buscar objetivo BOSS.
		var boss_objective: ObjectiveData = null

		for obj in semantic_result.objectives:
			if obj != null and obj.type == ObjectiveData.ObjectiveType.BOSS:
				boss_objective = obj
				break

		assert(
			boss_objective != null,
			"Seed %d: BOSS objective not found" % seed_val
		)

		# 4. Buscar RoomData correspondiente.
		var boss_room: RoomData = null

		for room in semantic_result.rooms:
			if room != null and room.id == boss_objective.room_id:
				boss_room = room
				break

		assert(
			boss_room != null,
			"Seed %d: Boss room %d not found" % [
				seed_val,
				boss_objective.room_id
			]
		)

		assert(
			semantic_result.boss_room_id == boss_room.id,
			"Seed %d: Semantic boss_room_id %d != RoomData.id %d" % [
				seed_val,
				semantic_result.boss_room_id,
				boss_room.id
			]
		)

		# 5. Crear staging root.
		var staging_root := Node3D.new()
		staging_root.name = "TestStagingRoot"
		root.add_child(staging_root)

		# 6. Materializar entidades.
		var spawn_result: Dictionary = entity_spawner.spawn_entities(
			semantic_result,
			staging_root,
			null,
			config
		)

		assert(
			spawn_result != null,
			"Seed %d: spawn_entities returned null" % seed_val
		)

		var spawned_entities: Array = spawn_result.get(
			"spawned_entities",
			[]
		)

		# 7. Buscar Boss Node3D materializado.
		var boss_node: Node3D = null

		for entity in spawned_entities:
			if entity == null:
				continue

			if not entity is Node3D:
				continue

			if not entity.has_meta("type"):
				continue

			if entity.get_meta("type") == ObjectiveData.ObjectiveType.BOSS:
				boss_node = entity as Node3D
				break

		assert(
			boss_node != null,
			"Seed %d: Boss Node3D was not materialized" % seed_val
		)

		# 8. Validar identidad.
		assert(
			boss_node.get_meta("type") == ObjectiveData.ObjectiveType.BOSS,
			"Seed %d: Boss Node has invalid type" % seed_val
		)

		assert(
			boss_node.get_meta("room_id") == boss_room.id,
			"Seed %d: Boss Node room_id %d != boss room %d" % [
				seed_val,
				boss_node.get_meta("room_id"),
				boss_room.id
			]
		)

		assert(
			boss_node.get_meta("objective_id") == boss_objective.objective_id,
			"Seed %d: Boss Node objective_id mismatch" % seed_val
		)

		# 9. Validar posición.
		var expected_grid_position: Vector2i = boss_room.get_walkable_point(
			semantic_result.grid
		)

		var expected_world_position: Vector3 = Vector3(
			(expected_grid_position.x + 0.5) * config.cell_size,
			0.2,
			(expected_grid_position.y + 0.5) * config.cell_size
		)

		assert(
			boss_node.position == expected_world_position,
			"Seed %d: Boss Node position mismatch. Expected %s, got %s" % [
				seed_val,
				str(expected_world_position),
				str(boss_node.position)
			]
		)

		staging_root.queue_free()

	print(
		"[PASS] test_boss_entity_materialization succeeded across %d seeds."
		% total_seeds
	)

	quit(0)