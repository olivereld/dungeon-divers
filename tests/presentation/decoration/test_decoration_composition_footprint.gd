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
	print("--- Running test_decoration_composition_footprint ---")
	print("==================================================================")

	var comp := DecorationCompositionScript.new(1)

	# 1. Registrar Sarcófago 2x1 en (4, 4) y (5, 4)
	var sarc_style := PropStyleScript.new(
		&"sarc", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(2, 1))
	)
	var sarc_dir := PropDirectiveScript.new(
		&"sarc", 1, sarc_style, Vector3(4, 0, 4), 0.0,
		[Vector2i(4, 4), Vector2i(5, 4)],
		PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING
	)
	assert(comp.add_prop_directive(sarc_dir), "FAIL: Sarcophagus should be accepted")
	assert(comp.get_occupied_cell_count() == 2, "FAIL: Expected 2 occupied cells for 2x1 footprint")
	print("  [OK] Multi-cell 2x1 footprint registered correctly.")

	# 2. Intentar colocar Tombstone 1x1 en celda secundaria (5, 4)
	var tomb_style := PropStyleScript.new(
		&"tomb", PropStyleScript.Type.TOMBSTONE, PropPlacementModeScript.Mode.WALL,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(1, 1))
	)
	var tomb_dir := PropDirectiveScript.new(
		&"tomb", 1, tomb_style, Vector3(5, 0, 4), 0.0,
		[Vector2i(5, 4)],
		PropPlacementModeScript.Mode.WALL, PropCollisionModeScript.Mode.BLOCKING
	)
	assert(not comp.add_prop_directive(tomb_dir), "FAIL: Tombstone on secondary cell of 2x1 footprint must be rejected")
	assert(comp.get_total_prop_count() == 1, "FAIL: Total prop count must remain 1")
	print("  [OK] Overlap rejection on secondary multi-cell footprint cell verified.")

	print("[PASS] test_decoration_composition_footprint completed successfully!")
	quit(0)
