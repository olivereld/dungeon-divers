extends SceneTree

const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_contracts ---")
	print("==================================================================")

	# 1. Test PropPlacementMode
	assert(PropPlacementModeScript.Mode.FLOOR == 0)
	assert(PropPlacementModeScript.Mode.WALL == 1)
	assert(PropPlacementModeScript.Mode.CENTER == 2)
	assert(PropPlacementModeScript.Mode.CORNER == 3)
	assert(PropPlacementModeScript.mode_to_name(PropPlacementModeScript.Mode.WALL) == "WALL")
	assert(PropPlacementModeScript.name_to_mode("center") == PropPlacementModeScript.Mode.CENTER)
	print("  [OK] PropPlacementMode validated.")

	# 2. Test PropCollisionMode
	assert(PropCollisionModeScript.Mode.NONE == 0)
	assert(PropCollisionModeScript.Mode.FOOTPRINT == 1)
	assert(PropCollisionModeScript.Mode.BLOCKING == 2)
	assert(PropCollisionModeScript.Mode.INTERACTIVE == 3)
	assert(PropCollisionModeScript.mode_to_name(PropCollisionModeScript.Mode.BLOCKING) == "BLOCKING")
	print("  [OK] PropCollisionMode validated.")

	# 3. Test PropFootprint
	var fp_1x1 := PropFootprintScript.new(Vector2i(1, 1))
	assert(fp_1x1.get_cell_count() == 1)
	var cells_1x1 = fp_1x1.get_occupied_cells(Vector2i(5, 5), 0.0)
	assert(cells_1x1.size() == 1 and cells_1x1[0] == Vector2i(5, 5))

	var fp_2x1 := PropFootprintScript.new(Vector2i(2, 1))
	assert(fp_2x1.get_cell_count() == 2)

	# 0 deg: (5,5), (6,5)
	var cells_rot0 = fp_2x1.get_occupied_cells(Vector2i(5, 5), 0.0)
	assert(cells_rot0.has(Vector2i(5, 5)) and cells_rot0.has(Vector2i(6, 5)))

	# 90 deg: (5,5), (5,4)
	var cells_rot90 = fp_2x1.get_occupied_cells(Vector2i(5, 5), 90.0)
	assert(cells_rot90.has(Vector2i(5, 5)) and cells_rot90.has(Vector2i(5, 4)))
	print("  [OK] PropFootprint rotation and cell occupancy validated.")

	# 4. Test PropStyle
	var style := PropStyleScript.new(
		&"test_sarcophagus",
		PropStyleScript.Type.SARCOPHAGUS,
		PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING,
		fp_2x1,
		&"sarcophagus_prop",
		{"style": 0}
	)
	assert(style.id == &"test_sarcophagus")
	assert(style.prop_type == PropStyleScript.Type.SARCOPHAGUS)
	assert(style.placement_mode == PropPlacementModeScript.Mode.CENTER)
	assert(style.collision_mode == PropCollisionModeScript.Mode.BLOCKING)
	assert(style.footprint.size == Vector2i(2, 1))
	print("  [OK] PropStyle resource validated.")

	print("[PASS] test_prop_contracts completed successfully!")
	quit(0)
