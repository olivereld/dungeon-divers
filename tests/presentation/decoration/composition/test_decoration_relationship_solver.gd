extends SceneTree

## Test suite para validar el motor de relaciones espaciales y simetría (DecorationRelationshipSolver).

const DecorationRelationshipSolverScript = preload("res://src/presentation/decoration/composition/decoration_relationship_solver.gd")
const DecorationRelationshipScript = preload("res://src/presentation/decoration/composition/decoration_relationship.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_decoration_relationship_solver ---")
	print("==================================================================")

	var solver := DecorationRelationshipSolverScript.new()

	# Crear sala simétrica 7x7 centrada en (4, 4)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 8):
		for y in range(1, 8):
			floor_cells.append(Vector2i(x, y))

	var room_geom = PresentationRoomGeometryScript.new(
		0,
		Rect2i(1, 1, 7, 7),
		floor_cells,
		[],
		[]
	)

	var center := Vector2i(4, 4)

	# 1. Validar Simetría (Espejado a través del centro o eje)
	var pos_left := Vector2i(2, 4)
	var symm_cells = solver.find_symmetric_positions(pos_left, center, room_geom)
	assert(symm_cells.has(Vector2i(6, 4)), "FAIL: Symmetric of (2,4) with center (4,4) must be (6,4)")

	# 2. Validar Proximidad (NEAR)
	var near_cells = solver.find_nearby_positions(Vector2i(4, 4), 1, 2, room_geom)
	assert(near_cells.has(Vector2i(4, 3)), "FAIL: (4,3) is near (4,4)")
	assert(near_cells.has(Vector2i(4, 5)), "FAIL: (4,5) is near (4,4)")
	assert(not near_cells.has(Vector2i(4, 4)), "FAIL: NEAR does not include the cell itself")

	# 3. Validar Adyacencia (ADJACENT)
	var adj_cells = solver.find_adjacent_positions(Vector2i(4, 4), room_geom)
	assert(adj_cells.size() == 4, "FAIL: Center of 7x7 has exactly 4 cardinal adjacent cells")
	assert(adj_cells.has(Vector2i(3, 4)) and adj_cells.has(Vector2i(5, 4)), "FAIL: Adjacent must include left/right")

	# 4. Validar Evaluación de Relaciones
	var ok_near = solver.is_relationship_satisfied(
		DecorationRelationshipScript.Relation.NEAR,
		Vector2i(5, 4),
		Vector2i(4, 4),
		room_geom
	)
	assert(ok_near == true, "FAIL: (5,4) is near (4,4)")

	var ok_away = solver.is_relationship_satisfied(
		DecorationRelationshipScript.Relation.KEEP_AWAY_FROM,
		Vector2i(7, 7),
		Vector2i(4, 4),
		room_geom
	)
	assert(ok_away == true, "FAIL: (7,7) is far from (4,4)")
	print("  [OK] DecorationRelationshipSolver symmetric reflections, near/adjacent finding and constraints verified.")

	print("==================================================================")
	print("[PASS] test_decoration_relationship_solver completado con 100% éxito!")
	print("==================================================================")
	quit(0)
