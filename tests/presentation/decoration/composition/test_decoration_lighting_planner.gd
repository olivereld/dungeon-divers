extends SceneTree

## Test suite para validar el planificador inteligente de iluminación por presupuesto (DecorationLightingPlanner).

const DecorationLightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_decoration_lighting_planner ---")
	print("==================================================================")

	var planner := DecorationLightingPlannerScript.new()
	var pal_resolver := DecorationPaletteResolverScript.new()
	var occupancy := DecorationOccupancyMapScript.new()

	# Crear sala de prueba 6x6 con puerta en (1, 3)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(0, 8):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 7))
	for y in range(1, 7):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(7, y))

	var room_geom = PresentationRoomGeometryScript.new(
		0,
		Rect2i(1, 1, 6, 6),
		floor_cells,
		wall_cells,
		[Vector2i(1, 3)]
	)

	# 1. Definir intención con presupuesto limitado (3.5)
	var intent := DecorationRoomIntentScript.new()
	intent.lighting_budget = 3.5

	# Paleta de Tumba
	var palette = pal_resolver.resolve_palette(1, RoomPurposeScript.Type.TOMB)
	assert(palette != null and palette.fixtures != null, "FAIL: Fixture palette resolved")

	var directives = planner.plan_room_lighting(
		intent.lighting_budget,
		intent,
		palette.fixtures,
		[], # primary_props
		room_geom,
		occupancy,
		1337,
		2.0
	)

	assert(directives != null, "FAIL: Directives array returned")
	assert(directives.size() >= 1 and directives.size() <= 4, "FAIL: Lighting directives must respect budget")

	# 2. Validar que ninguna luz se colocó sobre la puerta
	for dir in directives:
		assert(dir.cell != Vector2i(1, 3), "FAIL: Light directive must not block door cell (1,3)")

	print("  [OK] DecorationLightingPlanner budget consumption and door clearance verified.")

	print("==================================================================")
	print("[PASS] test_decoration_lighting_planner completado con 100% éxito!")
	print("==================================================================")
	quit(0)
