extends SceneTree

const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _ArchPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")

func _init() -> void:
	print("--- Running test_wall_torch_placement ---")
	var loader = _ProfileLoaderScript.new()
	var chamber_prof = loader.load_room("chamber.json")
	assert(chamber_prof != null, "Chamber profile must load")

	var planner = _DecorationCompPlannerScript.new()
	var pal_resolver = _DecorationPaletteResolverScript.new()

	var arch_prof = _ArchPresentationProfileScript.new(
		_ArchStyleScript.FloorStyle.CATACOMB_DIRT,
		_ArchStyleScript.WallStyle.DARK_STONE
	)
	var dec_palette = pal_resolver.resolve_palette(0, 0, arch_prof)

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
		[Vector2i(1, 4)],
		arch_prof
	)

	var comp = planner.plan_room_composition(
		chamber_prof,
		dec_palette,
		room_geom,
		null,
		null,
		1337,
		2.0
	)

	assert(comp != null, "Composition must exist")
	var wall_torch_count: int = 0
	for fd in comp.fixture_directives:
		print("  Placed fixture: ", fd.fixture_id, " at ", fd.world_position, " (placement: ", fd.placement.mode, ")")
		if fd.placement.mode == 0: # WALL
			wall_torch_count += 1

	assert(wall_torch_count >= chamber_prof.lighting.wall.min_count, "Expected at least %d wall fixtures, found %d" % [chamber_prof.lighting.wall.min_count, wall_torch_count])
	print("  [OK] Wall torches placed successfully: %d" % wall_torch_count)
	print("[PASS] test_wall_torch_placement passed!")
	quit(0)
