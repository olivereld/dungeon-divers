extends SceneTree

## Test suite para Commit 5: Identidad estricta RoomData -> Boss Spawn / Objective Mapping.
## Valida puramente sobre estructuras de datos (MissionGraph, RoomData, ObjectiveData, CellGrid) sin instanciar Node3D.

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonSemanticResult = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const ObjectiveData = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")

func _init() -> void:
	print("--- Running test_boss_entity_mapping (1000 seeds Boss Spawn Identity) ---")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var total_seeds: int = 1000

	for i in range(total_seeds):
		var seed_val: int = 200000 + i
		var config := DungeonConfig.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		config.boss_enabled = true

		# 1. Generación de DungeonResult base (Pipeline)
		var d_res: DungeonResult = pipeline.generate(config, DungeonPipeline.MAX_ATTEMPTS, true, false)
		assert(d_res != null, "Seed %d: DungeonPipeline returned null result" % seed_val)

		# 2. Identificar el nodo BOSS en MissionGraph
		var boss_node_id: int = -1
		for nid in d_res.mission_graph.get_all_node_ids():
			var nd: Dictionary = d_res.mission_graph.get_node_data(nid)
			if int(nd.get("action", -1)) == MissionNode.ActionType.BOSS:
				boss_node_id = nid
				break

		assert(boss_node_id != -1, "Seed %d: MissionNode BOSS must exist" % seed_val)

		# 3. Identificar la RoomData BOSS por coincidencia de misión
		var boss_room: RoomData = null
		var room_map: Dictionary = {}
		for room in d_res.rooms:
			room_map[room.id] = room
			if room.mission_node_id == boss_node_id:
				boss_room = room

		assert(boss_room != null, "Seed %d: RoomData with mission_node_id %d must exist" % [seed_val, boss_node_id])
		assert(boss_room.mission_node_id == boss_node_id, "Seed %d: Boss room mission_node_id must match boss_node_id" % seed_val)
		assert(boss_room.room_type == &"boss", "Seed %d: Boss room must have room_type 'boss'" % seed_val)

		# 4. Validar resolución de objetivos semánticos (Spawn / Objectives)
		var sem_res: DungeonSemanticResult = semantic_orchestrator.generate_semantic_layer(d_res, config, seed_val)
		assert(sem_res != null, "Seed %d: Semantic layer generation failed" % seed_val)
		assert(sem_res.boss_room_id == boss_room.id, "Seed %d: SemanticResult boss_room_id (%d) must match boss_room.id (%d)" % [
			seed_val, sem_res.boss_room_id, boss_room.id
		])

		var boss_objectives: Array = []
		for obj in sem_res.objectives:
			if obj.type == ObjectiveData.ObjectiveType.BOSS:
				boss_objectives.append(obj)

		assert(boss_objectives.size() == 1, "Seed %d: Expected exactly 1 BOSS objective, got %d" % [seed_val, boss_objectives.size()])

		var boss_obj: ObjectiveData = boss_objectives[0]
		var boss_spawn_room: RoomData = room_map.get(boss_obj.room_id, null)

		assert(boss_spawn_room != null, "Seed %d: Boss objective room must exist" % seed_val)
		assert(
			boss_spawn_room.mission_node_id == boss_node_id,
			"Seed %d: Boss spawn room mission_node_id %d does not match mission_node_id %d" % [
				seed_val, boss_spawn_room.mission_node_id, boss_node_id
			]
		)
		assert(
			boss_spawn_room.id == boss_room.id,
			"Seed %d: Boss spawn room ID %d does not match boss room ID %d" % [
				seed_val, boss_spawn_room.id, boss_room.id
			]
		)

	print("[PASS] test_boss_entity_mapping succeeded across %d seeds." % total_seeds)
	quit(0)
