extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("--- Running test_decoration_fixture_budget ---")

	var loader := _ProfileLoaderScript.new()
	var available = loader.list_available_archetypes()
	assert(not available.is_empty(), "FAIL: Must find archetypes")

	var arch_id: StringName = available[0]
	var bundle = loader.load_full_archetype_bundle(str(arch_id))
	assert(bundle != null, "FAIL: Must load bundle for %s" % str(arch_id))

	var first_room_id = bundle.rooms.keys()[0]
	var room_prof = bundle.rooms[first_room_id]

	var planner := _DecorationCompositionPlannerScript.new()
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

	var palette = pal_resolver.resolve_palette_by_id(arch_id, first_room_id)
	var seed_ctx = _PresentationSeedContextScript.for_room(555, 0)

	var comp = planner.plan_room_composition(
		room_prof,
		palette,
		room_geom,
		{"purpose": first_room_id},
		null,
		seed_ctx,
		2.0
	)

	assert(comp != null, "Composition must not be null")

	var light_source_count: int = 0
	var total_light_energy: float = 0.0

	for f_dir in comp.fixture_directives:
		if f_dir.style != null and f_dir.style.has_light:
			light_source_count += 1
			total_light_energy += f_dir.style.light_energy

	print("  [OK] Room '%s' fixtures resolved: %d total light sources, total energy = %0.2f" % [str(first_room_id), light_source_count, total_light_energy])
	assert(light_source_count <= 8, "Total light sources must respect budget (<= 8), got %d" % light_source_count)

	print("[PASS] test_decoration_fixture_budget completed successfully!")
	quit(0)
