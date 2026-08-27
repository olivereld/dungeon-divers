extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_pure_json_asset_pipeline ---")
	print("==================================================================")

	# 1. Verificar que PropAssetRegistry se inicializa con 0 hardcoding y carga props.json
	var registry := _PropAssetRegistryScript.new()
	assert(registry.get_definitions_count() >= 20, "FAIL: Registry must load at least 20 props from props.json")

	# 2. Verificar que un prop como pillar_stone proviene estrictamente de JSON
	assert(registry.has_definition(&"pillar_stone"), "FAIL: pillar_stone must be in registry")
	var pillar_def = registry.get_definition(&"pillar_stone")
	assert(pillar_def != null, "FAIL: pillar_stone definition must not be null")
	assert(pillar_def.has_variants(), "FAIL: pillar_stone must have variants from JSON")
	assert(pillar_def.variants.size() == 2, "FAIL: pillar_stone must have exactly 2 variants (intact/cracked)")

	# 3. Verificar que PropAssetProvider materializa el asset sin intermediarios en GDScript
	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)

	var node_intact = provider.materialize_by_id(&"pillar_stone", 1001)
	assert(node_intact != null, "FAIL: Must materialize pillar_stone")
	assert(node_intact.has_meta("variant_id"), "FAIL: Materialized node must have variant_id meta")
	print("  Materialized seed 1001 variant: ", node_intact.get_meta("variant_id"))
	assert(node_intact.scale == Vector3(3.0, 3.0, 3.0), "FAIL: Scale must match props.json definition (3.0)")
	node_intact.free()

	var node_cracked = provider.materialize_by_id(&"pillar_stone", 1005)
	assert(node_cracked != null, "FAIL: Must materialize pillar_stone")
	print("  Materialized seed 1005 variant: ", node_cracked.get_meta("variant_id"))
	node_cracked.free()

	# 4. Probar la colocación en una composición de habitación real
	var loader := _ProfileLoaderScript.new()
	var tomb_prof = loader.load_room("royal_tomb.json")
	assert(tomb_prof != null, "FAIL: royal_tomb.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 10, null)
	assert(palette != null, "FAIL: Palette must resolve")

	var planner := _DecorationCompPlannerScript.new()
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
		42,
		Rect2i(2, 2, 7, 7),
		f_cells,
		w_cells,
		[Vector2i(5, 2)],
		null,
		[]
	)

	var room_ctx = {"room_id": 1, "room_purpose": 10, "room_type": "NORMAL"}
	var seed_ctx = _PresentationSeedContextScript.for_room(42, 1)

	var comp = planner.plan_room_composition(
		tomb_prof,
		palette,
		room_geom,
		room_ctx,
		null,
		seed_ctx,
		2.0
	)
	assert(comp != null, "FAIL: Room composition must succeed")

	var spawner := _PropSpawnerScript.new(provider)
	var parent := Node3D.new()

	var spawned_pillar_count: int = 0
	for directive in comp.prop_directives:
		var n = spawner.spawn_prop(directive, parent)
		assert(n != null, "FAIL: Prop node must spawn")
		if directive.prop_id == &"pillar_stone":
			spawned_pillar_count += 1

	print("  Spawned pillars in Royal Tomb room: %d" % spawned_pillar_count)
	assert(spawned_pillar_count == 4, "FAIL: Exactly 4 pillars must spawn surrounding the sarcophagus")

	parent.free()

	print("==================================================================")
	print("[PASS] test_pure_json_asset_pipeline passed with 100% success!")
	print("==================================================================")
	quit(0)
