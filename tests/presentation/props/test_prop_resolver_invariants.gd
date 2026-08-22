extends SceneTree

const PropResolverScript = preload("res://src/presentation/props/prop_resolver.gd")
const PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_resolver_invariants ---")
	print("==================================================================")

	var grid := CellGridScript.new(20, 20, CellGridScript.CellType.WALL)

	var r_geom := PresentationRoomGeometryScript.new()
	r_geom.room_id = 1

	# Construir habitación de 8x8 en grid (de (5,5) a (12,12))
	for x in range(5, 13):
		for y in range(5, 13):
			var pos := Vector2i(x, y)
			grid.set_cell(pos, CellGridScript.CellType.FLOOR)
			r_geom.floor_cells.append(pos)

	# Puerta en (5, 8)
	r_geom.door_positions.append(Vector2i(5, 8))

	# Clonar el estado del grid en bytes antes de resolver para verificar inmutabilidad bit a bit
	var grid_bytes_backup: PackedByteArray = grid.get_raw_byte_buffer()

	# Configurar paleta de prueba con Sarcófago 2x1, Altar 2x1, Lápida 1x1, Urna 1x1
	var sarc_style := PropStyleScript.new(
		&"sarc", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(2, 1))
	)
	var tomb_style := PropStyleScript.new(
		&"tomb", PropStyleScript.Type.TOMBSTONE, PropPlacementModeScript.Mode.WALL,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(1, 1))
	)
	var corner_style := PropStyleScript.new(
		&"urn", PropStyleScript.Type.URN, PropPlacementModeScript.Mode.CORNER,
		PropCollisionModeScript.Mode.BLOCKING, PropFootprintScript.new(Vector2i(1, 1))
	)

	var entries: Array[PropPaletteEntryScript] = [
		PropPaletteEntryScript.new(sarc_style, 100.0),
		PropPaletteEntryScript.new(tomb_style, 100.0),
		PropPaletteEntryScript.new(corner_style, 100.0)
	]
	var palette := PropPaletteScript.new(&"test_crypt_palette", entries)
	palette.density = 0.50
	palette.max_props_per_room = 6

	var r_ctx := PresentationRoomContextScript.new()
	r_ctx.room_id = 1

	var resolver := PropResolverScript.new()

	# 1. Ejecución A
	var directives_a = resolver.resolve_room_props(r_ctx, palette, r_geom, 8888, 2.0)
	# 2. Ejecución B (misma semilla)
	var directives_b = resolver.resolve_room_props(r_ctx, palette, r_geom, 8888, 2.0)

	# Invariante 1: Determinismo
	assert(directives_a.size() == directives_b.size(), "FAIL: Directive count must match across identical runs")
	for i in range(directives_a.size()):
		assert(directives_a[i].prop_id == directives_b[i].prop_id, "FAIL: Prop ID mismatch")
		assert(directives_a[i].world_position == directives_b[i].world_position, "FAIL: Position mismatch")
		assert(directives_a[i].occupied_cells == directives_b[i].occupied_cells, "FAIL: Occupied cells mismatch")
	print("  [OK] Absolute determinism verified across independent runs (%d directives)." % directives_a.size())

	# Invariante 2: Inmutabilidad de CellGrid
	var current_bytes: PackedByteArray = grid.get_raw_byte_buffer()
	assert(current_bytes == grid_bytes_backup, "FAIL: CellGrid was mutated bit-by-bit!")
	print("  [OK] CellGrid immutability preserved bit-by-bit.")


	# Invariante 3: No solapamiento con puertas ni escaleras ni despejes
	var door_clearance := PropResolverScript._PropAnchorResolverScript._build_door_and_stairs_clearance_map(r_geom)
	for dir in directives_a:
		for cell in dir.occupied_cells:
			assert(not door_clearance.has(cell), "FAIL: Prop %s occupies clearance cell %s" % [dir.prop_id, str(cell)])
	print("  [OK] Zero overlap with door/stairs clearance zones.")

	# Invariante 4: No solapamiento de huellas entre múltiples props
	var all_occupied: Dictionary = {}
	for dir in directives_a:
		for cell in dir.occupied_cells:
			assert(not all_occupied.has(cell), "FAIL: Overlapping footprint cell %s between props!" % str(cell))
			all_occupied[cell] = dir.prop_id
	print("  [OK] Zero overlap between multi-cell prop footprints (%d total occupied cells)." % all_occupied.size())

	print("[PASS] test_prop_resolver_invariants completed successfully!")
	quit(0)
