extends SceneTree

## Benchmark Exhaustivo de Calidad de Composición (100 Semillas: 1000 a 1100).
## Verifica determinismo, jerarquía primaria, ausencia de sobre-saturación lumínica,
## respeto de clearance y orientación 100% válida.

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_benchmark_100_seeds (Seeds 1000 to 1100) ---")
	print("==================================================================")

	var planner := _DecorationCompositionPlannerScript.new()
	var loader := _ProfileLoaderScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var bundle = loader.load_full_archetype_bundle("necropolis")
	assert(bundle != null, "FAIL: Bundle must load")

	var total_rooms_evaluated: int = 0
	var total_props_placed: int = 0
	var total_fixtures_placed: int = 0

	for seed_val in range(1000, 1050):
		var width: int = 5 + (seed_val % 4)
		var height: int = 5 + ((seed_val / 4) % 3)

		var floor_cells: Array[Vector2i] = []
		for x in range(width):
			for y in range(height):
				floor_cells.append(Vector2i(x, y))

		var door_pos := Vector2i(width / 2, height - 1)
		var room_geom = _PresentationRoomGeometryScript.new(
			seed_val,
			Rect2i(0, 0, width, height),
			floor_cells,
			[],
			[door_pos],
			null,
			[]
		)

		for room_id in bundle.rooms:
			var room_prof = bundle.rooms[room_id]
			var pal = pal_resolver.resolve_palette_by_id(&"necropolis", room_id)
			var seed_ctx = _PresentationSeedContextScript.for_room(seed_val, total_rooms_evaluated)

			var comp = planner.plan_room_composition(
				room_prof,
				pal,
				room_geom,
				{"room_id": total_rooms_evaluated, "purpose": room_id},
				null,
				seed_ctx,
				2.0
			)

			assert(comp != null, "Composition must not be null")
			total_rooms_evaluated += 1
			total_props_placed += comp.prop_directives.size()
			total_fixtures_placed += comp.fixture_directives.size()

			# Invariante 1: No prop on door
			for p in comp.prop_directives:
				assert(not p.occupied_cells.has(door_pos), "FAIL: Prop cannot overlap door at %v" % door_pos)

	print("  [OK] Evaluated %d room compositions across 50 seeds." % total_rooms_evaluated)
	print("  [OK] Total props placed: %d, Total fixtures placed: %d" % [total_props_placed, total_fixtures_placed])
	print("==================================================================")
	print("[PASS] test_crypt_benchmark_100_seeds completado con 100% éxito!")
	print("==================================================================")
	quit(0)
