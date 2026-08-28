extends SceneTree

const DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_composition_determinism ---")
	print("==================================================================")

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1
	var floor_cells_map: Dictionary = {}
	for x in range(4, 14):
		for y in range(4, 14):
			var pos := Vector2i(x, y)
			r_geom.floor_cells.append(pos)
			floor_cells_map[pos] = true

	r_geom.door_positions.append(Vector2i(4, 8))

	var pal_resolver := DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette_by_id(&"necropolis", &"tomb")

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = &"tomb"

	var comp_resolver := DecorationCompositionResolverScript.new()

	# 1. Ejecuciones A y B con semilla idéntica (12345)
	var comp_a = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 12345, 2.0)
	var comp_b = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 12345, 2.0)

	assert(comp_a.get_total_prop_count() == comp_b.get_total_prop_count(), "FAIL: Prop count must match across identical seed runs")
	assert(comp_a.get_total_fixture_count() == comp_b.get_total_fixture_count(), "FAIL: Fixture count must match across identical seed runs")
	assert(comp_a.get_occupied_cell_count() == comp_b.get_occupied_cell_count(), "FAIL: Occupied cells count must match")

	for i in range(comp_a.prop_directives.size()):
		var pa = comp_a.prop_directives[i]
		var pb = comp_b.prop_directives[i]
		assert(pa.prop_id == pb.prop_id, "FAIL: Prop ID mismatch at index %d" % i)
		assert(pa.world_position == pb.world_position, "FAIL: Position mismatch at index %d" % i)
		assert(pa.rotation_degrees_y == pb.rotation_degrees_y, "FAIL: Rotation mismatch at index %d" % i)
		assert(pa.occupied_cells == pb.occupied_cells, "FAIL: Occupied cells mismatch at index %d" % i)
	print("  [OK] Absolute determinism verified across identical seeds (%d props, %d fixtures)." % [comp_a.get_total_prop_count(), comp_a.get_total_fixture_count()])

	# 2. Ejecución con semilla diferente (67890): debe producir composición válida y sin solapes
	var comp_other = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 67890, 2.0)
	assert(comp_other.get_total_prop_count() > 0, "FAIL: Expected props in different seed run")

	# Validar que todos los props están en el suelo, sin solapes y fuera de reservas
	var other_occupied: Dictionary = {}
	for p in comp_other.prop_directives:
		for cell in p.occupied_cells:
			assert(floor_cells_map.has(cell), "FAIL: Prop %s placed outside floor cells at %s" % [p.prop_id, str(cell)])
			assert(not comp_other.reserved_cells.has(cell), "FAIL: Prop %s occupies reserved cell at %s" % [p.prop_id, str(cell)])
			assert(not other_occupied.has(cell), "FAIL: Overlapping cell %s in different seed run" % str(cell))
			other_occupied[cell] = p.prop_id

	print("  [OK] Different seed run verified valid and strictly non-overlapping (%d props, %d cells)." % [comp_other.get_total_prop_count(), other_occupied.size()])
	print("[PASS] test_decoration_composition_determinism completed successfully!")
	quit(0)
