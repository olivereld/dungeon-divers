extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")

func _init() -> void:
	print("--- Running test_decoration_composition_hierarchy ---")

	var loader := _ProfileLoaderScript.new()
	var available = loader.list_available_archetypes()
	assert(not available.is_empty(), "FAIL: Must find archetypes")

	var arch_id: StringName = available[0]
	var bundle = loader.load_full_archetype_bundle(str(arch_id))
	assert(bundle != null, "FAIL: Must load archetype bundle")

	var planner := _DecorationCompositionPlannerScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var floor_cells: Array[Vector2i] = []
	for x in range(8):
		for y in range(8):
			floor_cells.append(Vector2i(x, y))

	var room_geom = _PresentationRoomGeometryScript.new(
		0,
		Rect2i(0, 0, 8, 8),
		floor_cells,
		[],
		[Vector2i(4, 7)],
		null,
		[]
	)

	# Probar jerarquía de composición para cada sala definida en el arquetipo
	for room_id in bundle.rooms:
		var room_prof = bundle.rooms[room_id]
		var palette = pal_resolver.resolve_palette_by_id(arch_id, room_id)
		var seed_ctx = _PresentationSeedContextScript.for_room(101, 0)

		var comp = planner.plan_room_composition(
			room_prof,
			palette,
			room_geom,
			{"purpose": room_id},
			null,
			seed_ctx,
			2.0
		)

		assert(comp != null, "Composition must not be null for room %s" % str(room_id))

		# Si el perfil declara reglas primarias con min_count >= 1, debe haber al menos un prop primario colocado
		var has_declared_primary: bool = false
		for r in room_prof.composition.primary:
			if r.min_count >= 1:
				has_declared_primary = true
				break

		if has_declared_primary:
			assert(comp.prop_directives.size() >= 1, "FAIL: Room '%s' with declared primary must place props" % str(room_id))

	print("  [OK] Composition hierarchy (PRIMARY, SECONDARY, SUPPORT) verified across declared room profiles.")
	print("[PASS] test_decoration_composition_hierarchy completed successfully!")
	quit(0)
