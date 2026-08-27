extends SceneTree

const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_pillar_placement ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var crypt_prof = loader.load_room("crypt.json")
	assert(crypt_prof != null, "FAIL: crypt.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 10, null)
	
	# Verify pillar entry exists in resolved prop palette
	var has_pillar := false
	for entry in palette.props.entries:
		if entry.style.id == &"pillar_stone" or entry.style.tags.has(&"pillar"):
			has_pillar = true
			break
	assert(has_pillar, "FAIL: Crypt prop palette must include pillar")

	# Test actual spatial placement in a 6x6 room
	var planner := _DecorationCompPlannerScript.new()
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
		1,
		Rect2i(2, 2, 6, 6),
		f_cells,
		w_cells,
		[Vector2i(4, 2)], # Door north
		null, # Profile
		[] # Stairs
	)

	var room_ctx = {"room_id": 1, "room_purpose": 10, "room_type": "NORMAL"}
	var seed_ctx = _PresentationSeedContextScript.for_room(1337, 1)

	var comp = planner.plan_room_composition(
		crypt_prof,
		palette,
		room_geom,
		room_ctx,
		null,
		seed_ctx,
		2.0
	)
	assert(comp != null, "FAIL: comp must not be null")
	
	var pillar_count: int = 0
	for d in comp.prop_directives:
		if d.prop_id == &"pillar_stone":
			pillar_count += 1
			print("  [OK] Placed pillar_stone at cells: ", d.occupied_cells, " pos: ", d.world_position)

	print("  Total pillars placed in Crypt: %d" % pillar_count)
	assert(pillar_count > 0, "FAIL: Expected at least 1 pillar to be placed in Crypt room")

	print("  [OK] Crypt composition successfully places pillar_stone.")
	print("==================================================================")
	print("[PASS] test_crypt_pillar_placement completed successfully!")
	print("==================================================================")
	quit(0)
