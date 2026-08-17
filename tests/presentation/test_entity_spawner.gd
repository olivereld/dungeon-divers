class_name TestEntitySpawner
extends SceneTree

const _EntitySpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_entity_spawner.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_entity_spawner ---")

	var spawner = _EntitySpawnerScript.new()
	var profile = _BiomeProfileScript.new()
	var staging_root := Node3D.new()

	var sem_res = _DungeonSemanticResultScript.new()

	# Configurar DoorPair para conexión 0
	var door_a := DoorPlacement.new(0, 0, Vector2i(5, 5), 0, Vector2i(5, 4), Vector2i(5, 5))
	var door_b := DoorPlacement.new(0, 1, Vector2i(5, 6), 1, Vector2i(5, 7), Vector2i(5, 6))
	var dp := DoorPair.new(0, door_a, door_b)
	sem_res.door_pairs.append(dp)

	# Añadir entidades semánticas desordenadas para verificar orden determinista
	sem_res.keys.append(_KeyDataScript.new(2, &"key_gold", 1, Vector2i(8, 8)))
	sem_res.keys.append(_KeyDataScript.new(1, &"key_iron", 0, Vector2i(2, 2)))

	sem_res.locks.append(_LockDataScript.new(1, 0, 0, 1, 1))

	sem_res.objectives.append(_ObjectiveDataScript.new(2, _ObjectiveDataScript.ObjectiveType.BOSS, 1, Vector2i(10, 10), true))
	sem_res.objectives.append(_ObjectiveDataScript.new(1, _ObjectiveDataScript.ObjectiveType.SPAWN, 0, Vector2i(2, 2), true))

	# Test 1: Spawning exitoso y determinista
	var res: Dictionary = spawner.spawn_entities(sem_res, staging_root, profile, null)
	assert(res["diagnostics"].is_empty(), "Valid entity setup should have 0 diagnostics")
	assert(res["spawned_entities"].size() == 5, "Should spawn 2 keys, 1 lock, 2 objectives")

	var entities_node := staging_root.get_node("Entities")
	assert(entities_node != null, "Entities root node should exist in staging")
	var keys_node := entities_node.get_node("Keys")
	assert(keys_node.get_child_count() == 2, "Should have 2 keys spawned")
	assert(keys_node.get_child(0).get_meta("key_id") == 1, "Keys must be sorted deterministically (id 1 first)")
	assert(keys_node.get_child(1).get_meta("key_id") == 2, "Keys must be sorted deterministically (id 2 second)")

	var locks_node := entities_node.get_node("Locks")
	assert(locks_node.get_child_count() == 1, "Should have 1 lock spawned")
	var lock_child: Node3D = locks_node.get_child(0) as Node3D
	assert(lock_child.get_meta("connection_id") == 0, "Lock connection_id should be 0")
	assert(lock_child.position == Vector3(5 * 2.0 + 1.0, 0.0, 5 * 2.0 + 1.0), "Lock position must match door_a exactly")
	print("  [OK] Test 1: Deterministic entity spawning with exact door positions verified")

	# Test 2: Error controlado de MISSING_DOOR_PAIR
	var staging_fail := Node3D.new()
	var sem_res_fail = _DungeonSemanticResultScript.new()
	sem_res_fail.locks.append(_LockDataScript.new(99, 999, 0, 1, 1)) # connection_id 999 no existe en door_pairs
	var res_fail: Dictionary = spawner.spawn_entities(sem_res_fail, staging_fail, profile, null)
	assert(res_fail["diagnostics"].size() == 1, "Missing door pair should generate diagnostic")
	assert(res_fail["diagnostics"][0]["code"] == "MISSING_DOOR_PAIR", "Diagnostic code must be MISSING_DOOR_PAIR")
	assert(res_fail["diagnostics"][0]["severity"] == "ERROR", "Diagnostic severity must be ERROR")
	print("  [OK] Test 2: Missing DoorPair properly reported with ERROR severity")

	staging_root.free()
	staging_fail.free()

	print("[PASS] test_entity_spawner succeeded with 100% assertions passing!")
	quit(0)
