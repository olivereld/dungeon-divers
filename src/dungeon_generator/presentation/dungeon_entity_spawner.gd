class_name DungeonEntitySpawner
extends RefCounted

## Materializa las entidades semánticas de la Fase 7 como nodos 3D dentro del StagingRoot.
## Respeta el orden determinista por ID y la autoridad estructural exclusiva de DoorPair para puertas/cerraduras.
## 100% puro: no muta el CellGrid ni recalcula puertas lógicas.

const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")

func spawn_entities(
	semantic_result: DungeonSemanticResult,
	staging_root: Node3D,
	biome: BiomeProfile,
	config: DungeonConfig = null
) -> Dictionary:
	# Retorna: {
	#   "spawned_entities": Array[Node],
	#   "diagnostics": Array[Dictionary]
	# }
	var diagnostics: Array[Dictionary] = []
	var spawned_entities: Array[Node] = []

	if semantic_result == null or staging_root == null:
		diagnostics.append({
			"code": "INVALID_ARGUMENTS",
			"severity": "FATAL",
			"stage": "entity_spawner",
			"entity_id": null,
			"message": "semantic_result or staging_root is null."
		})
		return { "spawned_entities": spawned_entities, "diagnostics": diagnostics }

	var tile_size: float = config.cell_size if config != null else 2.0

	# 1. Contenedor de Entidades en StagingRoot
	var entities_root := Node3D.new()
	entities_root.name = "Entities"
	staging_root.add_child(entities_root)

	var keys_root := Node3D.new()
	keys_root.name = "Keys"
	entities_root.add_child(keys_root)

	var locks_root := Node3D.new()
	locks_root.name = "Locks"
	entities_root.add_child(locks_root)

	var objectives_root := Node3D.new()
	objectives_root.name = "Objectives"
	entities_root.add_child(objectives_root)

	# 2. Ordenamiento Determinista por ID
	var sorted_keys: Array = semantic_result.keys.duplicate()
	sorted_keys.sort_custom(func(a, b): return a.key_id < b.key_id)

	var sorted_locks: Array = semantic_result.locks.duplicate()
	sorted_locks.sort_custom(func(a, b): return a.lock_id < b.lock_id)

	var sorted_objectives: Array = semantic_result.objectives.duplicate()
	sorted_objectives.sort_custom(func(a, b): return a.objective_id < b.objective_id)

	# 3. Spawning de Llaves (KeyData)
	for key in sorted_keys:
		var key_pos_3d := _GridToWorldScript.get_cell_center_world(key.position, tile_size, 0.2)
		var key_node: Node3D = null

		if biome != null and biome.key_scene != null:
			key_node = biome.key_scene.instantiate() as Node3D
		else:
			key_node = Marker3D.new()
			key_node.name = "Key_%d" % key.key_id

		if key_node != null:
			key_node.position = key_pos_3d
			key_node.set_meta("key_id", key.key_id)
			key_node.set_meta("room_id", key.room_id)
			key_node.set_meta("grid_pos", key.position)
			keys_root.add_child(key_node)
			spawned_entities.append(key_node)

	# 4. Spawning de Cerraduras (LockData) sobre DoorPair
	var door_pair_map: Dictionary = {}
	for dp in semantic_result.door_pairs:
		if dp != null:
			door_pair_map[dp.connection_id] = dp

	for lock in sorted_locks:
		if not door_pair_map.has(lock.connection_id):
			diagnostics.append({
				"code": "MISSING_DOOR_PAIR",
				"severity": "ERROR",
				"stage": "entity_spawner",
				"entity_id": lock.lock_id,
				"message": "Lock %d points to connection %d which has no valid DoorPair." % [lock.lock_id, lock.connection_id]
			})
			continue

		var dp: DoorPair = door_pair_map[lock.connection_id]
		# Usar posición y orientación exacta de DoorPair (autoridad estructural Fase 6.1.1)
		var door_a_pos: Vector2i = dp.door_a.position if dp.door_a != null else Vector2i.ZERO
		var lock_pos_3d := _GridToWorldScript.get_cell_center_world(door_a_pos, tile_size, 0.0)

		var lock_node: Node3D = null
		if biome != null and biome.locked_door_scene != null:
			lock_node = biome.locked_door_scene.instantiate() as Node3D
		elif biome != null and biome.door_scene != null:
			lock_node = biome.door_scene.instantiate() as Node3D
		else:
			lock_node = Marker3D.new()
			lock_node.name = "Lock_%d" % lock.lock_id

		if lock_node != null:
			lock_node.position = lock_pos_3d
			# Aplicar rotación canónica del marco de puerta
			if dp.door_a != null:
				lock_node.rotation.y = _side_to_rotation(dp.door_a.side)
			lock_node.set_meta("lock_id", lock.lock_id)
			lock_node.set_meta("connection_id", lock.connection_id)
			lock_node.set_meta("required_key_id", lock.required_key_id)
			locks_root.add_child(lock_node)
			spawned_entities.append(lock_node)

	# 5. Spawning de Objetivos (ObjectiveData)
	for obj in sorted_objectives:
		var obj_pos_3d := _GridToWorldScript.get_cell_center_world(obj.position, tile_size, 0.2)
		var obj_node: Node3D = null

		match obj.type:
			ObjectiveData.ObjectiveType.SPAWN:
				if biome != null and biome.spawn_scene != null:
					obj_node = biome.spawn_scene.instantiate() as Node3D
				else:
					obj_node = Marker3D.new()
					obj_node.name = "SpawnPoint"

			ObjectiveData.ObjectiveType.BOSS:
				if biome != null and biome.boss_scene != null:
					obj_node = biome.boss_scene.instantiate() as Node3D
				else:
					obj_node = Marker3D.new()
					obj_node.name = "BossPoint"

			ObjectiveData.ObjectiveType.TREASURE:
				if biome != null and biome.treasure_scene != null:
					obj_node = biome.treasure_scene.instantiate() as Node3D
				else:
					obj_node = Marker3D.new()
					obj_node.name = "TreasurePoint_%d" % obj.objective_id

			_:
				obj_node = Marker3D.new()
				obj_node.name = "Objective_%d" % obj.objective_id

		if obj_node != null:
			obj_node.position = obj_pos_3d
			obj_node.set_meta("objective_id", obj.objective_id)
			obj_node.set_meta("room_id", obj.room_id)
			obj_node.set_meta("type", obj.type)
			obj_node.set_meta("is_mandatory", obj.is_mandatory)
			objectives_root.add_child(obj_node)
			spawned_entities.append(obj_node)

	return {
		"spawned_entities": spawned_entities,
		"diagnostics": diagnostics
	}

func _side_to_rotation(side: int) -> float:
	match side:
		0: return 0.0        # NORTH
		1: return PI         # SOUTH
		2: return PI * 0.5   # WEST
		3: return -PI * 0.5  # EAST
		_: return 0.0
