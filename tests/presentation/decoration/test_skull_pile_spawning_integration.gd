extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_skull_pile_spawning_integration ---")
	print("==================================================================")

	# 1. Verificar registro data-driven de skull_pile
	var registry := _PropAssetRegistryScript.new()
	assert(registry.has_definition(&"skull_pile"), "FAIL: skull_pile must be defined in registry")
	var skull_def = registry.get_definition(&"skull_pile")
	assert(skull_def != null, "FAIL: skull_def must not be null")
	assert(skull_def.scene_path == "res://assets/scenes/props/skull_pile.tscn", "FAIL: scene_path should point to skull_pile.tscn")
	assert(skull_def.default_scale.distance_to(Vector3(0.8, 0.8, 0.8)) < 0.05, "FAIL: default scale must be 0.8")

	# 2. Verificar instanciación física del modelo 3D
	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)

	var skull_node = provider.materialize_by_id(&"skull_pile")
	assert(skull_node != null, "FAIL: skull_node must instantiate")
	assert(skull_node.name == "SkullPile" or skull_node.name.begins_with("SkullPile"), "FAIL: Root node name should be SkullPile")

	var static_body: StaticBody3D = null
	var col_shape: CollisionShape3D = null
	for child in skull_node.get_children():
		if child is StaticBody3D:
			static_body = child
			for subchild in child.get_children():
				if subchild is CollisionShape3D:
					col_shape = subchild

	assert(static_body != null, "FAIL: SkullPile scene must have StaticBody3D")
	assert(col_shape != null, "FAIL: SkullPile StaticBody3D must have CollisionShape3D")
	assert(col_shape.shape is CylinderShape3D, "FAIL: SkullPile collision shape must be CylinderShape3D")
	print("  [OK] Skull pile physical collider validated: ", col_shape.shape)
	skull_node.free()

	# 3. Verificar generación procedural en múltiples salas y semillas
	var loader := _ProfileLoaderScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var planner := _DecorationCompPlannerScript.new()
	var spawner := _PropSpawnerScript.new(provider)

	var tested_rooms: Dictionary = {
		"crypt.json": _RoomPurposeScript.Type.CRYPT,
		"tomb.json": _RoomPurposeScript.Type.TOMB,
		"chamber.json": _RoomPurposeScript.Type.CHAMBER,
		"royal_tomb.json": _RoomPurposeScript.Type.ROYAL_TOMB
	}

	for room_file in tested_rooms.keys():
		var purpose_type: int = tested_rooms[room_file]
		var profile = loader.load_room(room_file)
		assert(profile != null, "FAIL: Could not load " + room_file)

		var total_skulls_in_room_type := 0

		for seed_val in range(100, 150):
			var f_cells: Array[Vector2i] = []
			for x in range(2, 8):
				for y in range(2, 8):
					f_cells.append(Vector2i(x, y))

			var w_cells: Array[Vector2i] = []
			for x in range(1, 9):
				w_cells.append(Vector2i(x, 1))
				w_cells.append(Vector2i(x, 8))
			for y in range(2, 8):
				w_cells.append(Vector2i(1, y))
				w_cells.append(Vector2i(8, y))

			var room_geom = _PresentationRoomGeomScript.new(
				seed_val,
				Rect2i(2, 2, 6, 6),
				f_cells,
				w_cells,
				[Vector2i(4, 2)],
				null,
				[]
			)

			var palette = pal_resolver.resolve_palette(1, purpose_type, null)
			var room_ctx = {"room_id": 1, "room_purpose": purpose_type, "room_type": "NORMAL"}
			var seed_ctx = _PresentationSeedContextScript.for_room(seed_val, 1)

			var comp = planner.plan_room_composition(
				profile,
				palette,
				room_geom,
				room_ctx,
				null,
				seed_ctx,
				2.0
			)

			var parent := Node3D.new()
			for d in comp.prop_directives:
				if d.prop_id == &"skull_pile":
					total_skulls_in_room_type += 1
					var n = spawner.spawn_prop(d, parent)
					assert(n != null, "FAIL: skull_pile prop must spawn into parent")
			parent.free()

		print("  [OK] %s spawned %d skull piles over 50 test seeds" % [room_file, total_skulls_in_room_type])
		assert(total_skulls_in_room_type > 0, "FAIL: %s should spawn skull piles" % room_file)

	print("==================================================================")
	print("[PASS] test_skull_pile_spawning_integration passed with 100% success!")
	print("==================================================================")
	quit(0)
