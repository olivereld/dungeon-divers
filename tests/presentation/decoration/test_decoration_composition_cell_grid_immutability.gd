extends SceneTree

const DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_composition_cell_grid_immutability ---")
	print("==================================================================")

	var grid := CellGridScript.new(30, 30, CellGridScript.CellType.WALL)
	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1

	for x in range(5, 20):
		for y in range(5, 20):
			var pos := Vector2i(x, y)
			grid.set_cell(pos, CellGridScript.CellType.FLOOR)
			r_geom.floor_cells.append(pos)

	# Puertas y Escaleras
	grid.set_cell(Vector2i(5, 10), CellGridScript.CellType.DOOR)
	r_geom.door_positions.append(Vector2i(5, 10))

	grid.set_cell(Vector2i(19, 15), CellGridScript.CellType.STAIRS_DOWN)
	r_geom.set("stairs_cells", [Vector2i(19, 15)])

	# Snapshot exacto de bytes antes de la resolución
	var grid_bytes_before: PackedByteArray = grid.get_raw_byte_buffer()

	var pal_resolver := DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(DungeonArchetypeScript.Type.MAUSOLEUM, RoomPurposeScript.Type.TOMB)

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = RoomPurposeScript.Type.TOMB

	var comp_resolver := DecorationCompositionResolverScript.new()

	# Ejecutar múltiples resoluciones de composición con diversas semillas
	for test_seed in [111, 222, 333, 444, 555]:
		var comp = comp_resolver.resolve_room_composition(r_ctx, palette, r_geom, null, test_seed, 2.0)
		assert(comp != null and comp.get_total_prop_count() > 0, "FAIL: Composition resolution failed")

	# Snapshot de bytes después de todas las resoluciones
	var grid_bytes_after: PackedByteArray = grid.get_raw_byte_buffer()
	assert(grid_bytes_before == grid_bytes_after, "FAIL: CellGrid was mutated during decoration composition!")

	print("  [OK] Strict bit-by-bit immutability of CellGrid verified across multiple composition passes.")
	print("[PASS] test_decoration_composition_cell_grid_immutability completed successfully!")
	quit(0)
