extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_placement_driven_anchors ---")
	print("==================================================================")

	_test_wall_rule_discovers_wall_anchors()
	_test_center_rule_discovers_center_anchors()
	_test_corner_rule_discovers_corner_anchors()
	_test_floor_rule_discovers_floor_anchors()
	_test_fallback_uses_composition_role()

	print("[OK] All placement-driven anchor tests passed!")
	quit(0)

func _test_wall_rule_discovers_wall_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.SECONDARY
	rule.placement_mode = _PropPlacementModeScript.Mode.WALL

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: WALL rule must discover wall anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.WALL, "FAIL: All anchors must be WALL mode, got %d" % a.mode)
	print("  [OK] WALL rule discovers only WALL anchors (%d found)" % anchors.size())

func _test_center_rule_discovers_center_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.PRIMARY
	rule.placement_mode = _PropPlacementModeScript.Mode.CENTER

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: CENTER rule must discover center anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.CENTER, "FAIL: All anchors must be CENTER mode, got %d" % a.mode)
	print("  [OK] CENTER rule discovers only CENTER anchors (%d found)" % anchors.size())

func _test_corner_rule_discovers_corner_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.SECONDARY
	rule.placement_mode = _PropPlacementModeScript.Mode.CORNER

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: CORNER rule must discover corner anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.CORNER, "FAIL: All anchors must be CORNER mode, got %d" % a.mode)
	print("  [OK] CORNER rule discovers only CORNER anchors (%d found)" % anchors.size())

func _test_floor_rule_discovers_floor_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.DETAIL
	rule.placement_mode = _PropPlacementModeScript.Mode.FLOOR

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: FLOOR rule must discover floor anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.FLOOR, "FAIL: All anchors must be FLOOR mode, got %d" % a.mode)
	print("  [OK] FLOOR rule discovers only FLOOR anchors (%d found)" % anchors.size())

func _test_fallback_uses_composition_role() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.PRIMARY
	rule.placement_mode = -1  # Not set — should fall back to composition_role logic

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: Fallback must still produce anchors")
	print("  [OK] Fallback (placement_mode=-1) discovers anchors via composition_role (%d found)" % anchors.size())

const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _make_test_room_geom():
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 8):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 7))
	for y in range(1, 7):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(7, y))

	return _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 6, 6),
		floor_cells,
		wall_cells,
		[]
	)
