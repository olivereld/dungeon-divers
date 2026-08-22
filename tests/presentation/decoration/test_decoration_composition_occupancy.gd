extends SceneTree

const DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")
const PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_composition_occupancy ---")
	print("==================================================================")

	var comp := DecorationCompositionScript.new(1)

	var style_a := PropStyleScript.new(
		&"prop_a", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(2, 1))
	)
	var dir_a := PropDirectiveScript.new(
		&"prop_a", 1, style_a, Vector3(0, 0, 0), 0.0,
		[Vector2i(5, 5), Vector2i(6, 5)],
		PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING
	)

	# 1. Registrar Prop A: debe ser aceptado
	var accepted_a = comp.add_prop_directive(dir_a)
	assert(accepted_a, "FAIL: Prop A should be accepted")
	assert(comp.get_total_prop_count() == 1, "FAIL: Expected 1 prop registered")
	assert(comp.get_occupied_cell_count() == 2, "FAIL: Expected 2 occupied cells")
	assert(comp.occupied_cells.has(Vector2i(5, 5)) and comp.occupied_cells.has(Vector2i(6, 5)), "FAIL: Occupied cells must match footprint")
	print("  [OK] Prop A accepted and occupied cells registered.")

	# 2. Intentar registrar Prop B que solapa con celda (6, 5): debe ser rechazado
	var style_b := PropStyleScript.new(
		&"prop_b", PropStyleScript.Type.TOMBSTONE, PropPlacementModeScript.Mode.FLOOR,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(2, 1))
	)
	var dir_b := PropDirectiveScript.new(
		&"prop_b", 1, style_b, Vector3(2, 0, 0), 0.0,
		[Vector2i(6, 5), Vector2i(7, 5)],
		PropPlacementModeScript.Mode.FLOOR, PropCollisionModeScript.Mode.BLOCKING
	)

	var accepted_b = comp.add_prop_directive(dir_b)
	assert(not accepted_b, "FAIL: Prop B must be rejected due to overlap on (6, 5)")
	assert(comp.get_total_prop_count() == 1, "FAIL: Prop count must remain 1 after rejection")
	assert(comp.get_occupied_cell_count() == 2, "FAIL: Occupied cells count must remain 2")
	assert(not comp.occupied_cells.has(Vector2i(7, 5)), "FAIL: Unaccepted prop must not register any cells")
	print("  [OK] Prop B overlap rejection and state preservation verified.")

	print("[PASS] test_decoration_composition_occupancy completed successfully!")
	quit(0)
