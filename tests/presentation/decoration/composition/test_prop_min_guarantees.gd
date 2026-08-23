extends SceneTree

const _PlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileScript = preload("res://src/presentation/decoration/composition/decoration_composition_profile.gd")
const _DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const _PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const _PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _RuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("--- Running test_prop_min_guarantees ---")

	var planner := _PlannerScript.new()

	var floor_cells: Array[Vector2i] = []
	for x in range(1, 8):
		for y in range(1, 8):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 9):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 8))
	for y in range(1, 8):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(8, y))

	var geom = _PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 7, 7),
		floor_cells,
		wall_cells,
		[]
	)

	# Create an intentionally tight budget: max_total_props = 3
	# But we have 3 rules each with min_count = 1
	var profile := _ProfileScript.new()
	profile.max_total_props = 3

	var sarc := _PropStyleScript.new(&"sarcophagus", _PropStyleScript.Type.SARCOPHAGUS,
		_PropPlacementModeScript.Mode.CENTER, 0,
		_PropFootprintScript.new(Vector2i(2, 1)), &"sarcophagus", {},
		_DecorationRoleScript.Role.FOCAL, [_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL])
	var urn := _PropStyleScript.new(&"urn", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, 0,
		_PropFootprintScript.new(Vector2i.ONE), &"urn", {},
		_DecorationRoleScript.Role.SUPPORT, [_DecorationTagScript.BURIAL])
	var bench := _PropStyleScript.new(&"bench", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL, 0,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench", {},
		_DecorationRoleScript.Role.SUPPORT, [_DecorationTagScript.SEATING])

	var entries: Array[_PropPaletteEntryScript] = [
		_PropPaletteEntryScript.new(sarc, 1.0),
		_PropPaletteEntryScript.new(urn, 1.0),
		_PropPaletteEntryScript.new(bench, 1.0),
	]
	var prop_palette := _PropPaletteScript.new(&"test_palette", entries)
	prop_palette.max_props_per_room = 3

	# Rule 1: PRIMARY sarcophagus (min=1, max=2)
	var r1 := _RuleScript.new()
	r1.rule_id = &"primary"
	r1.composition_role = _CompositionRoleScript.Role.PRIMARY
	r1.placement_mode = _PropPlacementModeScript.Mode.CENTER
	r1.required_tags = [_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL]
	r1.min_count = 1
	r1.max_count = 2

	# Rule 2: SECONDARY urn (min=1, max=3)
	var r2 := _RuleScript.new()
	r2.rule_id = &"support_urn"
	r2.composition_role = _CompositionRoleScript.Role.SECONDARY
	r2.placement_mode = _PropPlacementModeScript.Mode.FLOOR
	r2.required_tags = [_DecorationTagScript.BURIAL]
	r2.min_count = 1
	r2.max_count = 3

	# Rule 3: SECONDARY bench (min=1, max=2)
	var r3 := _RuleScript.new()
	r3.rule_id = &"support_bench"
	r3.composition_role = _CompositionRoleScript.Role.SECONDARY
	r3.placement_mode = _PropPlacementModeScript.Mode.WALL
	r3.required_tags = [_DecorationTagScript.SEATING]
	r3.min_count = 1
	r3.max_count = 2

	profile.rules = [r1, r2, r3]

	# Build palette wrapper
	var dec_palette := _DecorationPaletteScript.new()
	dec_palette.props = prop_palette

	var seed_ctx := RefCounted.new()
	seed_ctx.set_meta("prop_seed", 42)
	seed_ctx.set_meta("fixture_seed", 42)

	var room_ctx := {"room_id": 0, "purpose": 0}

	var comp = planner.plan_room_composition(profile, dec_palette, geom, room_ctx, null, seed_ctx, 2.0)

	# ASSERTION: All 3 rules must have placed at least 1 prop each (their min_count)
	var has_sarc: bool = false
	var has_urn: bool = false
	var has_bench: bool = false
	for dir in comp.prop_directives:
		if dir.prop_id == &"sarcophagus":
			has_sarc = true
		elif dir.prop_id == &"urn":
			has_urn = true
		elif dir.prop_id == &"bench":
			has_bench = true

	assert(has_sarc, "PRIMARY sarcophagus must be guaranteed (min_count=1)")
	print("  [OK] PRIMARY sarcophagus guaranteed")
	assert(has_urn, "SECONDARY urn must be guaranteed (min_count=1)")
	print("  [OK] SECONDARY urn guaranteed")
	assert(has_bench, "SECONDARY bench must be guaranteed (min_count=1)")
	print("  [OK] SECONDARY bench guaranteed")
	assert(comp.prop_directives.size() <= 3, "Total props must respect max_total_props=3, got %d" % comp.prop_directives.size())
	print("  [OK] max_total_props respected")

	print("[PASS] test_prop_min_guarantees completed!")
	quit(0)
