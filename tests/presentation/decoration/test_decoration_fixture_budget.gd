extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("--- Running test_decoration_fixture_budget ---")

	var planner := _DecorationCompositionPlannerScript.new()
	var registry := _DecorationPurposeProfileRegistryScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var floor_cells: Array[Vector2i] = []
	for x in range(6):
		for y in range(6):
			floor_cells.append(Vector2i(x, y))

	var room_geom = _PresentationRoomGeometryScript.new(
		0,
		Rect2i(0, 0, 6, 6),
		floor_cells,
		[],
		[Vector2i(3, 5)],
		null,
		[]
	)

	var tomb_prof = registry.get_profile_for_purpose(_RoomPurposeScript.Type.TOMB)
	var tomb_pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, _RoomPurposeScript.Type.TOMB)

	var comp = planner.plan_room_composition(
		null,
		tomb_pal,
		room_geom,
		{"purpose": _RoomPurposeScript.Type.TOMB},
		null,
		{"prop_seed": 555, "fixture_seed": 777},
		2.0
	)

	assert(comp != null, "Composition must not be null")

	var light_source_count: int = 0
	var total_light_energy: float = 0.0

	for f_dir in comp.fixture_directives:
		if f_dir.style != null and f_dir.style.has_light:
			light_source_count += 1
			total_light_energy += f_dir.style.light_energy

	print("  [OK] Tomb Fixtures resolved: %d total light sources, total energy = %0.2f" % [light_source_count, total_light_energy])
	assert(light_source_count <= 6, "Total light sources must be balanced (<= 6), got %d" % light_source_count)

	print("[PASS] test_decoration_fixture_budget completed successfully!")
	quit(0)
