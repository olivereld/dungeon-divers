extends SceneTree

## Suite de pruebas unitarias para PR-10D: Proyección Espacial Multi-Piso (GridToWorld).

func _init() -> void:
	print("--- Running test_grid_to_world_multifloor (PR-10D) ---")

	var gtw_script = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")
	var tile_size: float = 2.0
	var floor_height: float = 6.0

	# 1. Validar floor_to_world_y
	assert(is_equal_approx(gtw_script.floor_to_world_y(0, floor_height), 0.0), "Floor 0 must be Y=0")
	assert(is_equal_approx(gtw_script.floor_to_world_y(1, floor_height), 6.0), "Floor 1 must be Y=6")
	assert(is_equal_approx(gtw_script.floor_to_world_y(3, floor_height), 18.0), "Floor 3 must be Y=18")
	print("  [OK] floor_to_world_y height calculation verified")

	# 2. Validar cell_to_world_3d
	var p_f0: Vector3 = gtw_script.cell_to_world_3d(Vector2i(4, 7), 0, tile_size, floor_height)
	assert(is_equal_approx(p_f0.x, 8.0) and is_equal_approx(p_f0.y, 0.0) and is_equal_approx(p_f0.z, 14.0), "F0 corner mismatch")

	var p_f2: Vector3 = gtw_script.cell_to_world_3d(Vector2i(4, 7), 2, tile_size, floor_height)
	assert(is_equal_approx(p_f2.x, 8.0) and is_equal_approx(p_f2.y, 12.0) and is_equal_approx(p_f2.z, 14.0), "F2 corner mismatch")
	print("  [OK] cell_to_world_3d corners verified")

	# 3. Validar get_cell_center_world_3d
	var center_f1: Vector3 = gtw_script.get_cell_center_world_3d(Vector2i(3, 5), 1, tile_size, floor_height, 0.5)
	assert(is_equal_approx(center_f1.x, 7.0), "Center X must be 3*2+1 = 7.0")
	assert(is_equal_approx(center_f1.y, 6.5), "Center Y must be 6.0 + 0.5 = 6.5")
	assert(is_equal_approx(center_f1.z, 11.0), "Center Z must be 5*2+1 = 11.0")
	print("  [OK] get_cell_center_world_3d center and offsets verified")

	# 4. Validar Proyección Inversa (world_to_cell_and_floor)
	var inv_res: Dictionary = gtw_script.world_to_cell_and_floor(Vector3(7.2, 6.3, 11.4), tile_size, floor_height)
	assert(inv_res["floor_number"] == 1, "Inverse projection must detect floor 1")
	assert(inv_res["cell"] == Vector2i(3, 5), "Inverse projection must detect cell (3, 5)")

	var inv_f0: Dictionary = gtw_script.world_to_cell_and_floor(Vector3(8.5, 0.1, 14.2), tile_size, floor_height)
	assert(inv_f0["floor_number"] == 0, "Inverse projection must detect floor 0")
	assert(inv_f0["cell"] == Vector2i(4, 7), "Inverse projection must detect cell (4, 7)")
	print("  [OK] Inverse projection (world_to_cell_and_floor) verified")

	print("\n>>> ALL PR-10D GRID-TO-WORLD MULTIFLOOR TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
