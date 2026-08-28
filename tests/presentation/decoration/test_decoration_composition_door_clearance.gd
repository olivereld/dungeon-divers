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
	print("--- Running test_decoration_composition_door_clearance ---")
	print("==================================================================")

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1
	for x in range(3, 11):
		for y in range(3, 11):
			r_geom.floor_cells.append(Vector2i(x, y))

	# Puerta en (3, 6)
	var door_pos := Vector2i(3, 6)
	r_geom.door_positions.append(door_pos)

	var pal_resolver := DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette_by_id(&"necropolis", &"tomb")

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = &"tomb"

	var comp_resolver := DecorationCompositionResolverScript.new()
	var comp = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, 98765, 2.0)

	# 1. Comprobar que la puerta y sus 8 vecinos están reservados
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var check_cell := door_pos + Vector2i(dx, dy)
			assert(comp.reserved_cells.has(check_cell), "FAIL: Clearance cell %s must be reserved" % str(check_cell))
	print("  [OK] Full 3x3 door clearance zone reserved.")

	# 2. Comprobar que ningún prop ocupa alguna de las celdas del despeje 3x3
	for p in comp.prop_directives:
		for cell in p.occupied_cells:
			assert(not comp.reserved_cells.has(cell), "FAIL: Prop %s occupies clearance cell %s" % [p.prop_id, str(cell)])
			var dist_x = absi(cell.x - door_pos.x)
			var dist_y = absi(cell.y - door_pos.y)
			assert(dist_x > 1 or dist_y > 1, "FAIL: Prop %s within 3x3 clearance box at %s" % [p.prop_id, str(cell)])

	print("  [OK] Zero props overlap with 3x3 door clearance zone.")
	print("[PASS] test_decoration_composition_door_clearance completed successfully!")
	quit(0)
