extends SceneTree

## Test suite para validar DecorationOccupancyMap (Huellas, Despejes y Superficies).

const DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_decoration_occupancy_map ---")
	print("==================================================================")

	var map := DecorationOccupancyMapScript.new()

	# 1. Registrar footprint
	var ok1 = map.add_footprint([Vector2i(2, 2), Vector2i(3, 2)], &"sarcophagus", 0)
	assert(ok1 == true, "FAIL: Sarcophagus footprint added successfully")
	assert(map.is_cell_occupied(Vector2i(2, 2)) == true, "FAIL: (2,2) is occupied")
	assert(map.is_cell_occupied(Vector2i(3, 2)) == true, "FAIL: (3,2) is occupied")
	assert(map.is_cell_occupied(Vector2i(4, 2)) == false, "FAIL: (4,2) is not occupied")

	# 2. Conflicto de footprint
	var ok_conflict = map.add_footprint([Vector2i(2, 2)], &"tombstone", 0)
	assert(ok_conflict == false, "FAIL: Conflicting footprint should be rejected")

	# 3. Anillos de despeje (Clearance)
	map.add_clearance([Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 3), Vector2i(3, 3)], &"sarcophagus")
	assert(map.has_clearance(Vector2i(2, 1)) == true, "FAIL: (2,1) has clearance")
	assert(map.is_area_available([Vector2i(2, 1)], true) == false, "FAIL: Area with clearance check should be unavailable")
	assert(map.is_area_available([Vector2i(2, 1)], false) == true, "FAIL: Area without clearance check should be available")

	# 4. Registro de superficies (Tabletop / Altar Top)
	map.register_surface(Vector2i(5, 5), &"tabletop", 0.78, &"wooden_table")
	assert(map.has_surface(Vector2i(5, 5)) == true, "FAIL: (5,5) has registered surface")
	var surf = map.get_surface(Vector2i(5, 5))
	assert(surf.surface_type == &"tabletop", "FAIL: Surface type is tabletop")
	assert(surf.height == 0.78, "FAIL: Surface height matches")
	assert(surf.owner_id == &"wooden_table", "FAIL: Owner id matches")
	print("  [OK] DecorationOccupancyMap footprints, clearances, and surfaces verified.")

	print("==================================================================")
	print("[PASS] test_decoration_occupancy_map completado con 100% éxito!")
	print("==================================================================")
	quit(0)
