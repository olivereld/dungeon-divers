extends SceneTree

## Suite de pruebas unitarias para PR-09D: Materialización de Puertas (DungeonDoorSpawner).

func _init() -> void:
	print("--- Running test_door_spawner (PR-09D) ---")

	var door_manifest_script = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
	var door_spawner_script = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
	var room_entrance_script = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

	# 1. Validar Cálculo de Posición 3D y Orientación por Lado
	# NORTH en (5, 5) con tile_size=2.0 -> Center X = 11.0, Y = 0.0, Z = 10.0
	var pos_north: Vector3 = door_spawner_script.calculate_door_world_position(Vector2i(5, 5), room_entrance_script.NORTH, 2.0)
	assert(is_equal_approx(pos_north.x, 11.0) and is_equal_approx(pos_north.z, 10.0), "North position must sit on north boundary (Z=10)")
	assert(is_equal_approx(door_spawner_script.calculate_door_orientation(room_entrance_script.NORTH), 0.0), "North orientation must be 0")

	# SOUTH en (5, 5) -> Center X = 11.0, Z = 12.0
	var pos_south: Vector3 = door_spawner_script.calculate_door_world_position(Vector2i(5, 5), room_entrance_script.SOUTH, 2.0)
	assert(is_equal_approx(pos_south.x, 11.0) and is_equal_approx(pos_south.z, 12.0), "South position must sit on south boundary (Z=12)")
	assert(is_equal_approx(door_spawner_script.calculate_door_orientation(room_entrance_script.SOUTH), PI), "South orientation must be PI")

	# WEST en (5, 5) -> X = 10.0, Center Z = 11.0
	var pos_west: Vector3 = door_spawner_script.calculate_door_world_position(Vector2i(5, 5), room_entrance_script.WEST, 2.0)
	assert(is_equal_approx(pos_west.x, 10.0) and is_equal_approx(pos_west.z, 11.0), "West position must sit on west boundary (X=10)")
	assert(is_equal_approx(door_spawner_script.calculate_door_orientation(room_entrance_script.WEST), PI * 0.5), "West orientation must be PI/2")

	# EAST en (5, 5) -> X = 12.0, Center Z = 11.0
	var pos_east: Vector3 = door_spawner_script.calculate_door_world_position(Vector2i(5, 5), room_entrance_script.EAST, 2.0)
	assert(is_equal_approx(pos_east.x, 12.0) and is_equal_approx(pos_east.z, 11.0), "East position must sit on east boundary (X=12)")
	assert(is_equal_approx(door_spawner_script.calculate_door_orientation(room_entrance_script.EAST), -PI * 0.5), "East orientation must be -PI/2")
	print("  [OK] Spatial calculations for all 4 door orientations verified")

	# 2. Validar Spawning de Puertas en StagingRoot
	var spawner := door_spawner_script.new()
	var staging := Node3D.new()

	var m1: DungeonDoorManifest = door_manifest_script.new("1", "conn_1_door_a", Vector2i(4, 7), Vector2i(4, 8), room_entrance_script.SOUTH)
	var m2: DungeonDoorManifest = door_manifest_script.new("1", "conn_1_door_b", Vector2i(4, 8), Vector2i(4, 7), room_entrance_script.NORTH)
	var manifests: Array[DungeonDoorManifest] = [m1, m2]

	var spawn_res: Dictionary = spawner.spawn_doors(manifests, staging, null, 2.0, 2, 42)
	assert(spawn_res["spawned_doors"].size() == 2, "Must spawn exactly 2 door entities")

	var doors_container: Node3D = staging.get_node_or_null("Doors")
	assert(doors_container != null, "Doors container node must exist in staging root")
	assert(doors_container.get_child_count() == 2, "Doors container must hold 2 child nodes")

	var door_1: Node3D = doors_container.get_node_or_null("DoorPortal_conn_1_door_a")
	assert(door_1 != null, "DoorPortal 1 must be instantiated")
	
	var stone_arch: MeshInstance3D = door_1.get_node_or_null("StoneArch")
	assert(stone_arch != null and stone_arch.mesh != null, "StoneArch must have valid mesh")
	assert(stone_arch.get_child_count() > 0, "StoneArch must have static collision")

	var door_entity = door_1.get_node_or_null("DoorEntity")
	assert(door_entity != null, "DoorEntity must exist inside portal")
	assert(door_entity.is_destructible, "DoorEntity must be destructible")
	
	# Probar interactividad básica
	assert(not door_entity.is_open, "Door must start closed")
	door_entity.open(true)
	assert(door_entity.is_open, "Door must be open after open()")
	door_entity.close(true)
	assert(not door_entity.is_open, "Door must be closed after close()")

	# Probar daño y destrucción
	door_entity.take_damage(50.0)
	assert(door_entity.current_health == 50.0, "Health must be 50 after taking 50 damage")
	door_entity.take_damage(60.0)
	assert(door_entity.is_destroyed(), "Door must be destroyed when health reaches 0")

	print("  [OK] DungeonDoorSpawner successfully instantiated procedural door portals with interactive/destructible entities")
	staging.free()
	print("\n>>> ALL PR-09D DOOR SPAWNER TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
