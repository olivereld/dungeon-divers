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
	print("--- Running test_decoration_composition_reservations ---")
	print("==================================================================")

	var comp := DecorationCompositionScript.new(1)

	# 1. Reservar celda (5, 5) por despeje
	comp.reserve_cell(Vector2i(5, 5), &"door_clearance")
	assert(comp.reserved_cells.has(Vector2i(5, 5)), "FAIL: Reserved cell not recorded")
	assert(comp.get_reserved_cell_count() == 1, "FAIL: Expected 1 reserved cell")

	# 2. Intentar colocar un prop en celda (5, 5)
	var style := PropStyleScript.new(
		&"urn_1", PropStyleScript.Type.URN, PropPlacementModeScript.Mode.FLOOR,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(1, 1))
	)
	var dir := PropDirectiveScript.new(
		&"urn_1", 1, style, Vector3(5, 0, 5), 0.0, [Vector2i(5, 5)],
		PropPlacementModeScript.Mode.FLOOR, PropCollisionModeScript.Mode.BLOCKING
	)

	var accepted = comp.add_prop_directive(dir)
	assert(not accepted, "FAIL: Prop placed on reserved cell must be rejected")
	assert(comp.get_total_prop_count() == 0, "FAIL: Prop count must be 0")
	assert(not comp.occupied_cells.has(Vector2i(5, 5)), "FAIL: Reserved cell must never become prop occupied cell")
	print("  [OK] Reservation protection and non-conversion to occupancy verified.")

	print("[PASS] test_decoration_composition_reservations completed successfully!")
	quit(0)
