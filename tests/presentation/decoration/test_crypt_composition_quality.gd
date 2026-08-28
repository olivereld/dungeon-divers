extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_composition_quality (Multi-Room & Multi-Seed) ---")
	print("==================================================================")

	var planner := _DecorationCompositionPlannerScript.new()
	var loader := _ProfileLoaderScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var bundle = loader.load_full_archetype_bundle("necropolis")
	assert(bundle != null, "FAIL: Bundle must load")

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

	for room_id in bundle.rooms:
		var room_prof = bundle.rooms[room_id]
		var pal = pal_resolver.resolve_palette_by_id(&"necropolis", room_id)

		for seed_val in [101, 202, 303, 404, 505]:
			var seed_ctx = _PresentationSeedContextScript.for_room(seed_val, 0)
			var comp = planner.plan_room_composition(
				room_prof,
				pal,
				room_geom,
				{"purpose": room_id},
				null,
				seed_ctx,
				2.0
			)

			assert(comp != null, "Composition must not be null for room %s" % str(room_id))

			for p in comp.prop_directives:
				assert(not p.occupied_cells.has(Vector2i(3, 5)), "Door clearance must be preserved in room %s" % str(room_id))

	print("  [OK] Multi-room and multi-seed composition quality validated across all bundle rooms.")
	print("==================================================================")
	print("[PASS] test_crypt_composition_quality completado con 100% éxito!")
	print("==================================================================")
	quit(0)
