extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_pipeline_integration ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var prof = loader.load_room("crypt.json")
	assert(prof != null, "FAIL: crypt.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 10, null)
	var planner := _DecorationCompPlannerScript.new()
	var spawner := _PropSpawnerScript.new()
	var service := _DestructionServiceScript.new()

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

	var room_geom = _PresentationRoomGeomScript.new(1337, Rect2i(2, 2, 6, 6), f_cells, w_cells, [Vector2i(4, 2)], null, [])
	var comp = planner.plan_room_composition(
		prof,
		palette,
		room_geom,
		{"room_id": 1, "room_purpose": 10, "room_type": "NORMAL"},
		null,
		_PresentationSeedContextScript.for_room(1337, 1),
		2.0
	)

	var parent := Node3D.new()
	var destructibles_found := 0
	var stats := {"events": 0}

	service.global_destruction_event.connect(func(evt):
		stats["events"] += 1
		print("  [Event Received] Target %s destroyed with mode %s" % [evt.target.name, evt.definition.destruction_mode])
	)

	for d in comp.prop_directives:
		var n = spawner.spawn_prop(d, parent)
		if n != null:
			var d_comp: _DestructionCompScript = null
			for c in n.get_children():
				if c is _DestructionCompScript:
					d_comp = c
			if d_comp != null:
				destructibles_found += 1
				service.register_instance(n, d_comp)
				# Apply fatal physical hit
				var hit_ok = service.apply_hit_to_node(n, _DestructionHitScript.new(100.0, &"physical"))
				assert(hit_ok, "FAIL: hit must apply to registered destructible")
				assert(d_comp.is_destroyed(), "FAIL: prop must be destroyed on fatal hit")

	print("  Found and destroyed %d procedural destructibles in generated crypt." % destructibles_found)
	assert(destructibles_found > 0, "FAIL: must have destructible props in room")
	assert(stats["events"] == destructibles_found, "FAIL: all destroyed events must be received")

	parent.free()
	print("==================================================================")
	print("[PASS] test_destruction_pipeline_integration passed 100%!")
	print("==================================================================")
	quit(0)
