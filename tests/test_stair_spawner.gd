extends SceneTree

## Suite de pruebas unitarias para PR-10G: DungeonStairSpawner.

func _init() -> void:
	print("--- Running test_stair_spawner (PR-10G) ---")

	var stair_spawner_script = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
	var stair_data_script = preload("res://src/dungeon_generator/core/data/stair_data.gd")

	var spawner := stair_spawner_script.new()
	var staging := Node3D.new()

	var st_up = stair_data_script.new("stair_f0_up", 0, Vector2i(5, 5), 0.0, "vconn_0_1", false)
	var st_down = stair_data_script.new("stair_f1_down", 1, Vector2i(5, 5), PI * 0.5, "vconn_0_1", true)
	var stairs: Array[StairData] = [st_up, st_down]

	# 1. Validar Spawning de Escaleras en Staging
	var spawn_res: Dictionary = spawner.spawn_stairs(stairs, staging, null, 2.0, 6.0, 1337)
	assert(spawn_res["spawned_stairs"].size() == 2, "Must spawn 2 stair entities")

	var stairs_container: Node3D = staging.get_node_or_null("Stairs")
	assert(stairs_container != null, "Stairs container must exist")
	assert(stairs_container.get_child_count() == 2, "Stairs container must have 2 children")

	# 2. Validar Posición 3D y Colisión
	var node_up: MeshInstance3D = stairs_container.get_node_or_null("Stair_stair_f0_up")
	assert(node_up != null and node_up.mesh != null, "Stair UP must be instantiated with valid mesh")
	assert(is_equal_approx(node_up.position.y, 0.0), "Stair UP on Floor 0 must be at Y=0.0")
	assert(is_equal_approx(node_up.position.x, 11.0) and is_equal_approx(node_up.position.z, 11.0), "Stair UP center X, Z mismatch")
	assert(node_up.get_child_count() > 0, "Stair UP must have collision body")

	var node_down: MeshInstance3D = stairs_container.get_node_or_null("Stair_stair_f1_down")
	assert(node_down != null and node_down.mesh != null, "Stair DOWN must be instantiated with valid mesh")
	assert(is_equal_approx(node_down.position.y, 6.0), "Stair DOWN on Floor 1 must be at Y=6.0")
	assert(is_equal_approx(node_down.rotation.y, PI * 0.5), "Stair DOWN rotation must match orientation")
	assert(node_down.get_child_count() > 0, "Stair DOWN must have collision body")

	# 3. Validar Superficies de Malla Procedural
	assert(node_up.mesh.get_surface_count() == 2, "Procedural stair mesh must contain 2 surfaces (StairSteps, StairRailings)")
	print("  [OK] DungeonStairSpawner procedural stair geometry, positioning, and collision verified")

	staging.free()
	print("\n>>> ALL PR-10G STAIR SPAWNER TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
