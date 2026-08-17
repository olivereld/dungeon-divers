class_name TestGridToWorld
extends SceneTree

const _GridToWorldScript = preload("res://src/dungeon_generator/presentation/grid_to_world.gd")

func _init() -> void:
	print("--- Running test_grid_to_world ---")

	# Test 1: Transformaciones canónicas con tile_size = 2.0 y height = 0.0
	var c0 := Vector2i(0, 0)
	var c1 := Vector2i(1, 0)
	var c2 := Vector2i(0, 1)
	var c3 := Vector2i(-1, 2)

	assert(_GridToWorldScript.cell_to_world(c0, 2.0, 0.0) == Vector3(0.0, 0.0, 0.0), "(0,0) -> (0,0,0)")
	assert(_GridToWorldScript.cell_to_world(c1, 2.0, 0.0) == Vector3(2.0, 0.0, 0.0), "(1,0) -> (2,0,0)")
	assert(_GridToWorldScript.cell_to_world(c2, 2.0, 0.0) == Vector3(0.0, 0.0, 2.0), "(0,1) -> (0,0,2)")
	assert(_GridToWorldScript.cell_to_world(c3, 2.0, 0.0) == Vector3(-2.0, 0.0, 4.0), "(-1,2) -> (-2,0,4)")
	print("  [OK] Test 1: Canonical cell_to_world coordinates verified: (0,0), (1,0), (0,1), (-1,2)")

	# Test 2: Alturas y tile_size diferentes
	var w_custom: Vector3 = _GridToWorldScript.cell_to_world(Vector2i(5, 10), 3.5, 1.5)
	assert(is_equal_approx(w_custom.x, 17.5) and is_equal_approx(w_custom.y, 1.5) and is_equal_approx(w_custom.z, 35.0),
		"Custom tile_size and height correctly applied")
	print("  [OK] Test 2: Custom tile sizes and heights correctly scaled")

	# Test 3: Reversibilidad bidireccional
	for test_cell in [c0, c1, c2, c3, Vector2i(42, -15)]:
		var w_pos := _GridToWorldScript.cell_to_world(test_cell, 2.0)
		var back_cell := _GridToWorldScript.world_to_cell(w_pos, 2.0)
		assert(back_cell == test_cell, "world_to_cell(cell_to_world(p)) must equal p")
	print("  [OK] Test 3: Bidirectional mapping world_to_cell is reversible")

	# Test 4: Centro de celda
	var center_c0 := _GridToWorldScript.get_cell_center_world(c0, 2.0, 0.5)
	assert(center_c0 == Vector3(1.0, 0.5, 1.0), "Center of (0,0) with size 2.0 should be (1, 0.5, 1)")
	print("  [OK] Test 4: get_cell_center_world offset verified")

	print("[PASS] test_grid_to_world succeeded with 100% assertions passing!")
	quit(0)
