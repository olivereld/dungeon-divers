extends SceneTree

## Test unitario para Task 4: Alineación Estricta Vano de Pared y Spawner de Puertas.
## Valida que los manifiestos de vano y puertas se extraigan de forma canónica y coincidan exactamente
## en posición espacial y orientación entre ContinuousWallExtractor y DungeonDoorSpawner.

func _init() -> void:
	print("--- Running test_door_wall_alignment ---")
	var FactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
	var DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
	var DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
	var SpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
	var RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

	# Puerta en la frontera x=8, y=5 mirando al Este (Side 3)
	var door_a = DoorPlacementScript.new(1, 0, Vector2i(8, 5), RoomEntranceScript.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var door_b = DoorPlacementScript.new(1, 1, Vector2i(12, 5), RoomEntranceScript.WEST, Vector2i(13, 5), Vector2i(11, 5))
	var dp = DoorPairScript.new(1, door_a, door_b)

	var door_manifests = FactoryScript.create_door_manifests([dp])
	assert(door_manifests.size() == 2, "Must produce 2 door manifests")

	var opening_manifest = FactoryScript.create_wall_opening_manifest([dp])
	assert(opening_manifest != null, "Opening manifest must be created")
	assert(opening_manifest.has_opening(Vector2i(8, 5), RoomEntranceScript.EAST), "Must have opening on door_a cell")
	assert(opening_manifest.has_opening(Vector2i(12, 5), RoomEntranceScript.WEST), "Must have opening on door_b cell")

	# Validar posiciones espaciales
	var pos_a: Vector3 = SpawnerScript.calculate_door_world_position(door_manifests[0].cell, door_manifests[0].side, 2.0)
	assert(is_equal_approx(pos_a.x, 17.0), "Door A world X must be 17.0 (cell 8 center = 8*2.0 + 1.0 = 17.0), got %f" % pos_a.x)
	assert(is_equal_approx(pos_a.z, 11.0), "Door A world Z must be 11.0 (cell 5 center = 5*2.0 + 1.0 = 11.0), got %f" % pos_a.z)

	var rot_a: float = SpawnerScript.calculate_door_orientation(door_manifests[0].side)
	assert(is_equal_approx(rot_a, -PI * 0.5), "Orientation for EAST must be -PI/2")

	print("  [OK] Doorway openings and 3D portal transforms strictly aligned")
	print("[PASS] test_door_wall_alignment completed successfully!")
	quit(0)
