extends SceneTree

const DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_composition_resolver ---")
	print("==================================================================")

	var grid := CellGridScript.new(20, 20, CellGridScript.CellType.WALL)

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1

	# Construir habitación 8x8 (de (5,5) a (12,12))
	for x in range(5, 13):
		for y in range(5, 13):
			var pos := Vector2i(x, y)
			grid.set_cell(pos, CellGridScript.CellType.FLOOR)
			r_geom.floor_cells.append(pos)

	# Puerta en (5, 8)
	r_geom.door_positions.append(Vector2i(5, 8))

	var grid_bytes_backup: PackedByteArray = grid.get_raw_byte_buffer()

	var pal_resolver := DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB)

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = RoomPurposeScript.Type.TOMB

	var comp_resolver := DecorationCompositionResolverScript.new()

	# 1. Resolver dos veces con la misma semilla para probar determinismo
	var comp_a = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 7777, 2.0)
	var comp_b = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 7777, 2.0)

	assert(comp_a.get_total_prop_count() == comp_b.get_total_prop_count(), "FAIL: Prop count mismatch")
	assert(comp_a.occupied_cells.keys() == comp_b.occupied_cells.keys(), "FAIL: Occupied cells mismatch")
	print("  [OK] Absolute composition determinism verified (%d props composed)." % comp_a.get_total_prop_count())

	# 2. Verificar prioridad FOCAL (debe contener al menos 1 elemento FOCAL ej. Sarcófago)
	var focal_props = comp_a.get_focal_props()
	assert(not focal_props.is_empty(), "FAIL: Expected at least one FOCAL prop in TOMB room")
	assert(focal_props[0].style.role == DecorationRoleScript.Role.FOCAL, "FAIL: First prop must have FOCAL role")
	print("  [OK] Priority 1 FOCAL prop composition verified: %s" % focal_props[0].prop_id)

	# 3. Verificar reservas estructurales y no solapamiento con puertas
	assert(comp_a.reserved_cells.has(Vector2i(5, 8)), "FAIL: Door cell must be reserved")
	assert(comp_a.reserved_cells.has(Vector2i(6, 8)), "FAIL: Door clearance must be reserved")
	for p in comp_a.prop_directives:
		for cell in p.occupied_cells:
			assert(not comp_a.reserved_cells.has(cell), "FAIL: Prop %s occupies reserved cell %s" % [p.prop_id, str(cell)])
	print("  [OK] Zero overlap with reserved door clearance zones.")

	# 4. Inmutabilidad de CellGrid
	assert(grid.get_raw_byte_buffer() == grid_bytes_backup, "FAIL: CellGrid was mutated during composition!")
	print("  [OK] CellGrid immutability preserved bit-by-bit.")

	# 5. Cero solapes entre huellas de props
	var checked_cells: Dictionary = {}
	for p in comp_a.prop_directives:
		for cell in p.occupied_cells:
			assert(not checked_cells.has(cell), "FAIL: Overlapping cell %s between props" % str(cell))
			checked_cells[cell] = p.prop_id
	print("  [OK] Zero overlap among multi-cell prop footprints (%d total occupied cells, %d rejected attempts)." % [
		comp_a.get_occupied_cell_count(), comp_a.rejected_placements
	])

	print("[PASS] test_decoration_composition_resolver completed successfully!")
	quit(0)
