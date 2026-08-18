extends SceneTree

## Suite de pruebas unitarias para PR-09A: Contratos Geométricos de Puertas y Vanos.

func _init() -> void:
	print("--- Running test_door_and_opening_manifests (PR-09A) ---")

	var door_manifest_script = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
	var wall_opening_script = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")

	# 1. Validar DungeonDoorManifest
	var door_manifest: DungeonDoorManifest = door_manifest_script.new(
		"conn_12", "door_12_a", Vector2i(4, 5), Vector2i(4, 6), 2
	)
	assert(door_manifest.connection_id == "conn_12", "Connection ID must match")
	assert(door_manifest.door_id == "door_12_a", "Door ID must match")
	assert(door_manifest.cell == Vector2i(4, 5), "Cell must match")
	assert(door_manifest.adjacent_cell == Vector2i(4, 6), "Adjacent cell must match")
	assert(door_manifest.side == 2, "Side must match")
	assert(is_equal_approx(door_manifest.get_orientation_radians(), PI), "SOUTH orientation must be PI")
	print("  [OK] DungeonDoorManifest contract verified")

	# 2. Validar WallOpeningManifest y Regla de Unicidad
	var opening_manifest: WallOpeningManifest = wall_opening_script.new()
	assert(opening_manifest.size() == 0, "Initial manifest must be empty")

	var added_1: bool = opening_manifest.add_opening(Vector2i(10, 5), 0, "conn_1")
	assert(added_1, "First addition must succeed")
	assert(opening_manifest.size() == 1, "Size must be 1")
	assert(opening_manifest.has_opening(Vector2i(10, 5), 0), "Opening must exist at (10, 5, NORTH)")
	assert(not opening_manifest.has_opening(Vector2i(10, 5), 1), "Opening must not exist at (10, 5, EAST)")
	assert(not opening_manifest.has_opening(Vector2i(10, 6), 0), "Opening must not exist at (10, 6, NORTH)")

	# Invariante de Unicidad: Duplicado debe ser rechazado
	var added_dup: bool = opening_manifest.add_opening(Vector2i(10, 5), 0, "conn_duplicate")
	assert(not added_dup, "Duplicate addition for same (cell, side) must be rejected")
	assert(opening_manifest.size() == 1, "Size must remain 1 after rejected duplicate")

	# Agregar otro lado de la misma celda
	var added_2: bool = opening_manifest.add_opening(Vector2i(10, 5), 1, "conn_2")
	assert(added_2, "Different side on same cell must be allowed")
	assert(opening_manifest.size() == 2, "Size must be 2")

	var cell_openings: Array = opening_manifest.get_openings_for_cell(Vector2i(10, 5))
	assert(cell_openings.size() == 2, "Cell (10, 5) must return 2 openings")

	print("  [OK] WallOpeningManifest contract and uniqueness invariants verified")
	print("\n>>> ALL PR-09A CONTRACT TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
