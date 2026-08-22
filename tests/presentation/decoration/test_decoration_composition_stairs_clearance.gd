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
	print("--- Running test_decoration_composition_stairs_clearance ---")
	print("==================================================================")

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1
	for x in range(5, 15):
		for y in range(5, 15):
			r_geom.floor_cells.append(Vector2i(x, y))

	# Escaleras en (10, 10)
	var stairs_pos := Vector2i(10, 10)
	r_geom.stairs_positions.append(stairs_pos)

	var pal_resolver := DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.CRYPT)

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = RoomPurposeScript.Type.CRYPT

	var comp_resolver := DecorationCompositionResolverScript.new()
	var comp = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 54321, 2.0)

	# 1. Comprobar que la celda de escaleras y su caja 3x3 están reservadas
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var check_cell := stairs_pos + Vector2i(dx, dy)
			assert(comp.reserved_cells.has(check_cell), "FAIL: Stairs clearance cell %s must be reserved" % str(check_cell))
	print("  [OK] Full 3x3 stairs clearance zone reserved.")

	# 2. Comprobar que ningún prop ocupa la zona de escaleras
	for p in comp.prop_directives:
		for cell in p.occupied_cells:
			assert(not comp.reserved_cells.has(cell), "FAIL: Prop %s occupies stairs clearance cell %s" % [p.prop_id, str(cell)])
			var dist_x = absi(cell.x - stairs_pos.x)
			var dist_y = absi(cell.y - stairs_pos.y)
			assert(dist_x > 1 or dist_y > 1, "FAIL: Prop %s within 3x3 stairs clearance box at %s" % [p.prop_id, str(cell)])

	print("  [OK] Zero props overlap with 3x3 stairs clearance zone.")
	print("[PASS] test_decoration_composition_stairs_clearance completed successfully!")
	quit(0)
