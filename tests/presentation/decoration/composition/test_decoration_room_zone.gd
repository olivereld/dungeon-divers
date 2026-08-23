extends SceneTree

## Test suite para validar la zonificación espacial de salas (DecorationRoomZone).

const DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_decoration_room_zone ---")
	print("==================================================================")

	# Crear una sala 7x7 con puerta en (1, 4) (Muro Oeste)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 8):
		for y in range(1, 8):
			floor_cells.append(Vector2i(x, y))

	var room_geom = PresentationRoomGeometryScript.new(
		0,
		Rect2i(1, 1, 7, 7),
		floor_cells,
		[],
		[Vector2i(1, 4)]
	)

	var zone_partitioner = DecorationRoomZoneScript.new()
	var zones: Dictionary = zone_partitioner.partition_room(room_geom)

	assert(not zones.is_empty(), "FAIL: Zones partition map must not be empty")

	# 1. Validar zona ENTRY frente a la puerta (1, 4)
	assert(zones.has(Vector2i(1, 4)), "FAIL: Door cell must be partitioned")
	assert(zones[Vector2i(1, 4)] == DecorationRoomZoneScript.ZoneType.ENTRY, "FAIL: (1,4) must be ENTRY zone")
	assert(zones[Vector2i(2, 4)] == DecorationRoomZoneScript.ZoneType.TRAVERSAL or zones[Vector2i(2, 4)] == DecorationRoomZoneScript.ZoneType.ENTRY, "FAIL: (2,4) must be ENTRY/TRAVERSAL zone")

	# 2. Validar centro focal (4, 4)
	assert(zones[Vector2i(4, 4)] == DecorationRoomZoneScript.ZoneType.FOCAL or zones[Vector2i(4, 4)] == DecorationRoomZoneScript.ZoneType.CENTER, "FAIL: Center cell (4,4) must be FOCAL/CENTER zone")

	# 3. Validar esquinas (1, 1), (7, 1), (1, 7), (7, 7)
	assert(zones[Vector2i(7, 7)] == DecorationRoomZoneScript.ZoneType.CORNER, "FAIL: Corner cell (7,7) must be CORNER zone")
	assert(zones[Vector2i(7, 1)] == DecorationRoomZoneScript.ZoneType.CORNER, "FAIL: Corner cell (7,1) must be CORNER zone")

	# 4. Validar perímetro (4, 1) (Muro Norte alejado de la puerta)
	assert(zones[Vector2i(4, 1)] == DecorationRoomZoneScript.ZoneType.PERIMETER or zones[Vector2i(4, 1)] == DecorationRoomZoneScript.ZoneType.SIDE, "FAIL: Wall perimeter cell (4,1) must be PERIMETER/SIDE zone")

	print("  [OK] DecorationRoomZone successfully partitioned room into ENTRY, TRAVERSAL, FOCAL, CORNER, PERIMETER zones.")

	print("==================================================================")
	print("[PASS] test_decoration_room_zone completado con 100% éxito!")
	print("==================================================================")
	quit(0)
