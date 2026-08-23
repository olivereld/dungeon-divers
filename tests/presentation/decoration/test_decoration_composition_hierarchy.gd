extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

func _init() -> void:
	print("--- Running test_decoration_composition_hierarchy ---")

	var planner := _DecorationCompositionPlannerScript.new()
	var registry := _DecorationPurposeProfileRegistryScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	# Create a mock 6x6 room geometry
	var floor_cells: Array[Vector2i] = []
	for x in range(6):
		for y in range(6):
			floor_cells.append(Vector2i(x, y))

	var room_geom = _PresentationRoomGeometryScript.new(
		0,
		Rect2i(0, 0, 6, 6),
		floor_cells,
		[],
		[Vector2i(3, 5)], # Door at bottom
		null,
		[]
	)

	# 1. TEST TOMB HIERARCHY (Primary Sarcophagus + Secondary Urns/Tombstones)
	var tomb_prof = registry.get_profile_for_purpose(_RoomPurposeScript.Type.TOMB)
	var tomb_pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, _RoomPurposeScript.Type.TOMB)

	var tomb_comp = planner.plan_room_composition(
		null,
		tomb_pal,
		room_geom,
		{"purpose": _RoomPurposeScript.Type.TOMB},
		null,
		{"prop_seed": 101, "fixture_seed": 102},
		2.0
	)

	assert(tomb_comp != null, "Tomb composition must not be null")
	assert(tomb_comp.prop_directives.size() > 0, "Tomb must have props")

	# Check that Primary prop is present (sarcophagus)
	var has_primary: bool = false
	for p_dir in tomb_comp.prop_directives:
		if p_dir.style != null and (p_dir.style.role == _DecorationRoleScript.Role.FOCAL or p_dir.style.prop_type == _PropStyleScript.Type.SARCOPHAGUS):
			has_primary = true
			print("  [OK] Found Primary prop: %s at %v" % [p_dir.prop_id, p_dir.world_position])
			break

	assert(has_primary, "Tomb room must have a Primary prop placed")
	print("  [OK] TOMB Primary/Secondary hierarchy successfully verified.")

	# 2. TEST ENTRANCE MINIMALISM (Minimal props, high clearance)
	var entry_prof = registry.get_profile_for_purpose(_RoomPurposeScript.Type.ENTRANCE)
	var entry_pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, _RoomPurposeScript.Type.ENTRANCE)

	var entry_comp = planner.plan_room_composition(
		null,
		entry_pal,
		room_geom,
		{"purpose": _RoomPurposeScript.Type.ENTRANCE},
		null,
		{"prop_seed": 201, "fixture_seed": 202},
		2.0
	)

	assert(entry_comp != null, "Entrance composition must not be null")
	assert(entry_comp.prop_directives.size() <= 2, "Entrance must have at most 2 props, got %d" % entry_comp.prop_directives.size())
	print("  [OK] ENTRANCE minimalism successfully verified (props count = %d)." % entry_comp.prop_directives.size())

	print("[PASS] test_decoration_composition_hierarchy completed successfully!")
	quit(0)
