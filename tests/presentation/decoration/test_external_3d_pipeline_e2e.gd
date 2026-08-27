extends SceneTree

const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_external_3d_pipeline_e2e (100 Seeds) ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var tomb_prof = loader.load_room("royal_tomb.json")
	assert(tomb_prof != null, "FAIL: royal_tomb.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 10, null)
	assert(palette != null, "FAIL: palette must resolve")

	var planner := _DecorationCompPlannerScript.new()
	var registry := _PropAssetRegistryScript.new()
	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)
	var spawner := _PropSpawnerScript.new(provider)

	var total_pillars: int = 0
	var total_procedural_props: int = 0
	var variant_counts: Dictionary = {}

	for seed_val in range(1000, 1100):
		var f_cells: Array[Vector2i] = []
		for x in range(2, 9):
			for y in range(2, 9):
				f_cells.append(Vector2i(x, y))

		var w_cells: Array[Vector2i] = []
		for x in range(1, 10):
			w_cells.append(Vector2i(x, 1))
			w_cells.append(Vector2i(x, 9))
		for y in range(2, 9):
			w_cells.append(Vector2i(1, y))
			w_cells.append(Vector2i(9, y))

		var room_geom = _PresentationRoomGeomScript.new(
			seed_val,
			Rect2i(2, 2, 7, 7),
			f_cells,
			w_cells,
			[Vector2i(5, 2)],
			null,
			[]
		)

		var room_ctx = {"room_id": 1, "room_purpose": 10, "room_type": "NORMAL"}
		var seed_ctx = _PresentationSeedContextScript.for_room(seed_val, 1)

		var comp = planner.plan_room_composition(
			tomb_prof,
			palette,
			room_geom,
			room_ctx,
			null,
			seed_ctx,
			2.0
		)
		assert(comp != null, "FAIL: comp must not be null for seed %d" % seed_val)

		var parent := Node3D.new()

		for directive in comp.prop_directives:
			var node = spawner.spawn_prop(directive, parent)
			assert(node != null, "FAIL: prop %s must spawn" % str(directive.prop_id))

			if directive.prop_id == &"pillar_stone":
				total_pillars += 1
				var var_id = node.get_meta("variant_id") if node.has_meta("variant_id") else "pillar_stone_intact"
				variant_counts[var_id] = variant_counts.get(var_id, 0) + 1
			else:
				total_procedural_props += 1

		parent.free()

	print("  Total 3D pillar props spawned over 100 seeds: %d" % total_pillars)
	print("  Variant distribution for 3D pillars: ", variant_counts)
	print("  Total procedural props (sarcophagus, etc.) spawned: %d" % total_procedural_props)

	assert(total_pillars >= 400, "FAIL: Expected 4 pillars per Royal Tomb (400 across 100 seeds), got %d" % total_pillars)
	assert(total_procedural_props >= 100, "FAIL: Expected at least 100 procedural props, got %d" % total_procedural_props)
	assert(variant_counts.size() >= 2, "FAIL: Expected both intact and cracked variants to spawn")

	print("==================================================================")
	print("[PASS] test_external_3d_pipeline_e2e passed with 100% success!")
	print("==================================================================")
	quit(0)
