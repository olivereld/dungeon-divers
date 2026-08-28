extends SceneTree

## Test suite E2E para validar DecorationCompositionPlanner con perfiles reales cargados desde JSON.

const DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_planner_e2e ---")
	print("==================================================================")

	var loader := ProfileLoaderScript.new()
	var available_archetypes = loader.list_available_archetypes()
	assert(not available_archetypes.is_empty(), "FAIL: Must discover available archetypes")

	var target_arch: StringName = available_archetypes[0]
	var bundle = loader.load_full_archetype_bundle(str(target_arch))
	assert(bundle != null, "FAIL: Must load archetype bundle")

	var planner := DecorationCompositionPlannerScript.new()
	var pal_resolver := DecorationPaletteResolverScript.new()

	# 1. Crear geometría de sala de prueba (6x6)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells.append(Vector2i(x, y))

	var room_geom = PresentationRoomGeometryScript.new(
		0,
		Rect2i(1, 1, 6, 6),
		floor_cells,
		[],
		[Vector2i(1, 4)]
	)

	# 2. Planificar composición para cada sala definida en el bundle
	for room_id in bundle.rooms:
		var room_prof = bundle.rooms[room_id]
		var palette = pal_resolver.resolve_palette_by_id(target_arch, room_id)
		var seed_ctx = PresentationSeedContextScript.for_room(1337, 0)

		var comp = planner.plan_room_composition(
			room_prof,
			palette,
			room_geom,
			{"room_id": 0, "purpose": room_id},
			null,
			seed_ctx,
			2.0
		)

		assert(comp != null, "FAIL: Composition result is null for room %s" % str(room_id))

		# Verificar que ningún prop solape la puerta (1, 4)
		for p_dir in comp.prop_directives:
			assert(not p_dir.occupied_cells.has(Vector2i(1, 4)), "FAIL: Prop %s in room %s must not overlap door" % [str(p_dir.prop_id), str(room_id)])

	print("  [OK] DecorationCompositionPlanner successfully planned compositions for all JSON room profiles without door conflicts.")
	print("==================================================================")
	print("[PASS] test_composition_planner_e2e completado con 100% éxito!")
	print("==================================================================")
	quit(0)
