extends SceneTree

## Test suite para validar DecorationOrientationMode y DecorationPlacementConstraint.

const DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")
const DecorationPlacementConstraintScript = preload("res://src/presentation/decoration/composition/decoration_placement_constraint.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_placement_constraints ---")
	print("==================================================================")

	# 1. Validar DecorationOrientationMode
	assert(DecorationOrientationModeScript.Mode.FACE_ROOM == 0)
	assert(DecorationOrientationModeScript.Mode.FACE_WALL == 1)
	assert(DecorationOrientationModeScript.Mode.FACE_CENTER == 2)
	assert(DecorationOrientationModeScript.Mode.ALIGN_WALL == 3)
	assert(DecorationOrientationModeScript.Mode.ALIGN_AXIS == 4)
	assert(DecorationOrientationModeScript.Mode.FREE == 5)
	assert(DecorationOrientationModeScript.mode_to_name(DecorationOrientationModeScript.Mode.FACE_ROOM) == "FACE_ROOM")
	assert(DecorationOrientationModeScript.name_to_mode("align_wall") == DecorationOrientationModeScript.Mode.ALIGN_WALL)
	print("  [OK] DecorationOrientationMode enum and conversions verified.")

	# 2. Validar DecorationPlacementConstraint
	var constraint := DecorationPlacementConstraintScript.new()
	assert(constraint.cannot_overlap == true)
	assert(constraint.cannot_touch_door == true)
	assert(constraint.cannot_touch_stairs == true)
	assert(constraint.must_be_floor == true)
	assert(constraint.must_have_clear_approach == false)
	assert(constraint.min_clearance_cells == 0)

	var violations = constraint.check_hard_constraints(
		[Vector2i(2, 2)], # footprint
		{Vector2i(2, 2): true}, # floor_map
		{Vector2i(2, 3): &"door_clearance"}, # reserved_map
		{}, # occupied_map
		[Vector2i(2, 3)] # door_positions
	)
	assert(violations.is_empty(), "FAIL: Footprint at (2,2) with door at (2,3) should be valid if not overlapping")

	# Conflicto directo con celda ocupada
	var conflict_violations = constraint.check_hard_constraints(
		[Vector2i(2, 2)],
		{Vector2i(2, 2): true},
		{},
		{Vector2i(2, 2): &"sarcophagus"},
		[]
	)
	assert(conflict_violations.has(&"CANNOT_OVERLAP"), "FAIL: Overlapping cell must return CANNOT_OVERLAP violation")
	print("  [OK] DecorationPlacementConstraint hard validation verified.")

	print("==================================================================")
	print("[PASS] test_placement_constraints completado con 100% éxito!")
	print("==================================================================")
	quit(0)
