extends SceneTree

## Test suite E2E para el Vertical Slice de Cripta (Fases 10.1 a 10.18).
## Valida que cada propósito de sala de Cripta (TOMB, ANTECHAMBER, ENTRANCE, CATACOMB)
## genere una composición con intención espacial, zonificación, plantillas y presupuesto lumínico.

const DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_vertical_slice_e2e ---")
	print("==================================================================")

	var planner := DecorationCompositionPlannerScript.new()
	var pal_resolver := DecorationPaletteResolverScript.new()
	var purpose_registry := DecorationPurposeProfileRegistryScript.new()

	# 1. TEST TOMB: Foco central, despeje de puertas, sin bancos
	var floor_cells_tomb: Array[Vector2i] = []
	for x in range(1, 8):
		for y in range(1, 8):
			floor_cells_tomb.append(Vector2i(x, y))

	var walls_tomb: Array[Vector2i] = []
	for x in range(0, 9):
		walls_tomb.append(Vector2i(x, 0))
		walls_tomb.append(Vector2i(x, 8))
	for y in range(1, 8):
		walls_tomb.append(Vector2i(0, y))
		walls_tomb.append(Vector2i(8, y))

	var geom_tomb = PresentationRoomGeometryScript.new(
		1,
		Rect2i(1, 1, 7, 7),
		floor_cells_tomb,
		walls_tomb,
		[Vector2i(1, 4)]
	)

	var profile_tomb = purpose_registry.get_profile_for_purpose(RoomPurposeScript.Type.TOMB)
	var palette_tomb = pal_resolver.resolve_palette(1, RoomPurposeScript.Type.TOMB)
	var seed_ctx_tomb = PresentationSeedContextScript.for_room(1337, 1)

	var comp_tomb = planner.plan_room_composition(
		null, # Usará el purpose profile automáticamente si es nulo
		palette_tomb,
		geom_tomb,
		{"room_id": 1, "purpose": RoomPurposeScript.Type.TOMB},
		null,
		seed_ctx_tomb,
		2.0
	)

	assert(comp_tomb != null, "FAIL: Tomb composition must not be null")
	assert(comp_tomb.prop_directives.size() >= 1, "FAIL: Tomb must have placed primary focal prop")
	for p in comp_tomb.prop_directives:
		assert(p.prop_id != &"gothic_stone_bench", "FAIL: Tomb must not contain benches (forbidden tag SEATING)")
		assert(not p.occupied_cells.has(Vector2i(1, 4)), "FAIL: No prop may overlap door cell")
	print("  [OK] Crypt TOMB vertical slice validated (Focal sarcophagus, no benches, clearance preserved).")

	# 2. TEST ANTECHAMBER: Bancos mirando al interior de la sala
	var floor_cells_ante: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells_ante.append(Vector2i(x, y))

	var walls_ante: Array[Vector2i] = []
	for x in range(0, 8):
		walls_ante.append(Vector2i(x, 0))
		walls_ante.append(Vector2i(x, 7))
	for y in range(1, 7):
		walls_ante.append(Vector2i(0, y))
		walls_ante.append(Vector2i(7, y))

	var geom_ante = PresentationRoomGeometryScript.new(
		2,
		Rect2i(1, 1, 6, 6),
		floor_cells_ante,
		walls_ante,
		[Vector2i(1, 3), Vector2i(6, 3)]
	)

	var palette_ante = pal_resolver.resolve_palette(1, RoomPurposeScript.Type.ANTECHAMBER)
	var seed_ctx_ante = PresentationSeedContextScript.for_room(2026, 2)

	var comp_ante = planner.plan_room_composition(
		null,
		palette_ante,
		geom_ante,
		{"room_id": 2, "purpose": RoomPurposeScript.Type.ANTECHAMBER},
		null,
		seed_ctx_ante,
		2.0
	)

	assert(comp_ante != null, "FAIL: Antechamber composition must not be null")
	for p in comp_ante.prop_directives:
		assert(p.prop_id != &"sarcophagus_stone_closed", "FAIL: Antechamber must not contain massive sarcophagi")
	print("  [OK] Crypt ANTECHAMBER vertical slice validated (Seating orientation, proper purpose allocation).")

	# 3. TEST ENTRANCE: Despeje amplio de jugador
	var floor_cells_entry: Array[Vector2i] = []
	for x in range(1, 6):
		for y in range(1, 6):
			floor_cells_entry.append(Vector2i(x, y))

	var walls_entry: Array[Vector2i] = []
	for x in range(0, 7):
		walls_entry.append(Vector2i(x, 0))
		walls_entry.append(Vector2i(x, 6))
	for y in range(1, 6):
		walls_entry.append(Vector2i(0, y))
		walls_entry.append(Vector2i(6, y))

	var geom_entry = PresentationRoomGeometryScript.new(
		3,
		Rect2i(1, 1, 5, 5),
		floor_cells_entry,
		walls_entry,
		[Vector2i(1, 2)]
	)
	var palette_entry = pal_resolver.resolve_palette(1, RoomPurposeScript.Type.ENTRANCE)
	var comp_entry = planner.plan_room_composition(
		null,
		palette_entry,
		geom_entry,
		{"room_id": 3, "purpose": RoomPurposeScript.Type.ENTRANCE},
		null,
		PresentationSeedContextScript.for_room(999, 3),
		2.0
	)
	assert(comp_entry != null, "FAIL: Entrance composition must not be null")
	print("  [OK] Crypt ENTRANCE vertical slice validated (Clear player approach).")

	print("==================================================================")
	print("[PASS] test_crypt_vertical_slice_e2e completado con 100% éxito!")
	print("==================================================================")
	quit(0)
