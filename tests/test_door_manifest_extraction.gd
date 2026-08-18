extends SceneTree

## Suite de pruebas unitarias para PR-09B: Extracción de Manifiestos desde Core.

func _init() -> void:
	print("--- Running test_door_manifest_extraction (PR-09B) ---")

	var door_placement_script = preload("res://src/dungeon_generator/core/data/door_placement.gd")
	var door_pair_script = preload("res://src/dungeon_generator/core/data/door_pair.gd")
	var door_factory_script = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
	var room_entrance_script = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

	# 1. Crear pares de prueba
	# Puerta A: Habitación 1 en (5, 5), mira al ESTE (3) hacia el corredor (6, 5)
	var placement_a = door_placement_script.new(
		1, 1, Vector2i(5, 5), room_entrance_script.EAST, Vector2i(4, 5), Vector2i(6, 5)
	)
	# Puerta B: Habitación 2 en (10, 5), mira al OESTE (2) hacia el corredor (9, 5)
	var placement_b = door_placement_script.new(
		1, 2, Vector2i(10, 5), room_entrance_script.WEST, Vector2i(11, 5), Vector2i(9, 5)
	)

	var pair = door_pair_script.new(1, placement_a, placement_b)
	var door_pairs: Array = [pair]

	# 2. Validar Extracción de DungeonDoorManifest
	var door_manifests: Array = door_factory_script.create_door_manifests(door_pairs)
	assert(door_manifests.size() == 2, "Must extract exactly 2 door manifests from 1 pair")

	var m_a = door_manifests[0]
	assert(m_a.connection_id == "1", "Connection ID must match")
	assert(m_a.door_id == "conn_1_room_1_a", "Door ID must match format")
	assert(m_a.cell == Vector2i(5, 5), "Cell must match placement position")
	assert(m_a.adjacent_cell == Vector2i(6, 5), "Adjacent cell must match corridor_cell")
	assert(m_a.side == room_entrance_script.EAST, "Side must match EAST")

	var m_b = door_manifests[1]
	assert(m_b.connection_id == "1", "Connection ID must match")
	assert(m_b.door_id == "conn_1_room_2_b", "Door ID must match format")
	assert(m_b.cell == Vector2i(10, 5), "Cell must match placement position")
	assert(m_b.side == room_entrance_script.WEST, "Side must match WEST")
	print("  [OK] create_door_manifests successfully converted DoorPairs to neutral manifests")

	# 3. Validar Generación de WallOpeningManifest
	var opening_manifest = door_factory_script.create_wall_opening_manifest(door_pairs)
	assert(opening_manifest.size() == 4, "Must register 4 openings (2 per door: forward and reverse faces)")

	# Validar vanos para Puerta A
	assert(opening_manifest.has_opening(Vector2i(5, 5), room_entrance_script.EAST), "Opening at (5, 5, EAST) must exist")
	assert(opening_manifest.has_opening(Vector2i(6, 5), room_entrance_script.WEST), "Reverse opening at (6, 5, WEST) must exist")

	# Validar vanos para Puerta B
	assert(opening_manifest.has_opening(Vector2i(10, 5), room_entrance_script.WEST), "Opening at (10, 5, WEST) must exist")
	assert(opening_manifest.has_opening(Vector2i(9, 5), room_entrance_script.EAST), "Reverse opening at (9, 5, EAST) must exist")

	print("  [OK] create_wall_opening_manifest successfully registered oriented edge openings")
	print("\n>>> ALL PR-09B EXTRACTION TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
