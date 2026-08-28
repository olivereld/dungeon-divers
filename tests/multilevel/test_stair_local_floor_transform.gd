extends SceneTree

## Suite de pruebas de regresión: Transformación local de escaleras por piso (Local Floor Space).

func _init() -> void:
	print("--- Running test_stair_local_floor_transform ---")

	var stair_spawner_script = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
	var stair_data_script = preload("res://src/dungeon_generator/core/data/stair_data.gd")

	var spawner := stair_spawner_script.new()

	# 1. Probar Floor 0 (UP) en su propio floor_container
	var floor_0_container := Node3D.new()
	floor_0_container.name = "Floor_0"
	var st_f0_up = stair_data_script.new("stair_f0_up", 0, Vector2i(4, 4), 0.0, "vconn_0_1", false)
	var res_f0: Dictionary = spawner.spawn_stairs([st_f0_up], floor_0_container, null, 2.0, 6.0, 1337, null, [], true)

	assert(res_f0["spawned_stairs"].size() == 1, "Floor 0 must spawn 1 stair")
	var node_f0_up: Node3D = floor_0_container.get_node("Stairs/Stair_stair_f0_up")
	assert(node_f0_up != null, "Stair UP node must exist in Floor 0")
	assert(is_equal_approx(node_f0_up.position.y, 0.0), "Floor 0 UP stair local Y must be 0.0")
	print("  [OK] Floor 0 UP local Y = 0.0 verified.")

	# 2. Probar Floor 1 (DOWN) en su propio floor_container
	var floor_1_container := Node3D.new()
	floor_1_container.name = "Floor_1"
	var st_f1_down = stair_data_script.new("stair_f1_down", 1, Vector2i(6, 6), PI * 0.5, "vconn_0_1", true)
	var res_f1: Dictionary = spawner.spawn_stairs([st_f1_down], floor_1_container, null, 2.0, 6.0, 1337, null, [], true)

	assert(res_f1["spawned_stairs"].size() == 1, "Floor 1 must spawn 1 stair")
	var node_f1_down: Node3D = floor_1_container.get_node("Stairs/Stair_stair_f1_down")
	assert(node_f1_down != null, "Stair DOWN node must exist in Floor 1")
	assert(is_equal_approx(node_f1_down.position.y, 0.0), "Floor 1 DOWN stair local Y must be 0.0 (NO double elevation offset)")
	assert(is_equal_approx(node_f1_down.rotation.y, PI * 0.5), "Stair rotation must match orientation")
	print("  [OK] Floor 1 DOWN local Y = 0.0 verified.")

	# 3. Probar modo legado Global Space (use_local_floor_space = false)
	var global_staging := Node3D.new()
	var res_global: Dictionary = spawner.spawn_stairs([st_f0_up, st_f1_down], global_staging, null, 2.0, 6.0, 1337, null, [], false)
	var g_f0: Node3D = global_staging.get_node("Stairs/Stair_stair_f0_up")
	var g_f1: Node3D = global_staging.get_node("Stairs/Stair_stair_f1_down")
	assert(is_equal_approx(g_f0.position.y, 0.0), "Global space Floor 0 Y must be 0.0")
	assert(is_equal_approx(g_f1.position.y, 6.0), "Global space Floor 1 Y must be 6.0")
	print("  [OK] Global space fallback mode verified.")

	floor_0_container.free()
	floor_1_container.free()
	global_staging.free()

	print("\n==================================================================")
	print("[PASS] test_stair_local_floor_transform passed 100%!")
	print("==================================================================\n")
	quit(0)
