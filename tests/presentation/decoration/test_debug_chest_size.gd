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
	print("--- Running test_debug_chest_size ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var tomb_prof = loader.load_room("royal_tomb.json")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 14, null)

	var planner := _DecorationCompPlannerScript.new()
	var registry := _PropAssetRegistryScript.new()
	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)
	var spawner := _PropSpawnerScript.new(provider)

	var def = registry.get_definition(&"chest_wooden")
	print("chest_wooden def in registry: default_scale=", def.default_scale if def != null else "NULL")

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
		1337,
		Rect2i(2, 2, 7, 7),
		f_cells,
		w_cells,
		[Vector2i(5, 2)],
		null,
		[]
	)

	var room_ctx = {"room_id": 1, "room_purpose": 14, "room_type": "NORMAL"}
	var seed_ctx = _PresentationSeedContextScript.for_room(1337, 1)

	var comp = planner.plan_room_composition(
		tomb_prof,
		palette,
		room_geom,
		room_ctx,
		null,
		seed_ctx,
		2.0
	)

	var parent := Node3D.new()
	for directive in comp.prop_directives:
		var node = spawner.spawn_prop(directive, parent)
		print("Spawned prop: name=", node.name, " prop_id=", directive.prop_id, " scale=", node.scale, " global_scale=", node.global_transform.basis.get_scale())
		if directive.prop_id == &"chest_wooden":
			for c in node.get_children():
				print("   child: ", c.name, " scale=", c.scale)

	parent.free()
	print("==================================================================")
	quit(0)
