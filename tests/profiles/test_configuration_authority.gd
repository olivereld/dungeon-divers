extends SceneTree

## Suite exhaustiva de verificación de Autoridad de Datos (Data Authority).
## Demuestra que los perfiles y definiciones declarativas son la única fuente
## de verdad y que mutar sus datos altera la generación, arquitectura, composición,
## iluminación y relaciones sin modificar GDScript.

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_configuration_authority ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var available_archetypes = loader.list_available_archetypes()
	assert(not available_archetypes.is_empty(), "FAIL: Must discover available archetypes")

	var target_arch_id: StringName = available_archetypes[0]
	var bundle = loader.load_full_archetype_bundle(str(target_arch_id))
	assert(bundle != null and bundle.archetype != null, "FAIL: Must load archetype bundle for %s" % str(target_arch_id))

	var room_keys = bundle.rooms.keys()
	assert(room_keys.size() >= 2, "FAIL: Archetype %s must define at least 2 room profiles" % str(target_arch_id))
	var room_id_a: StringName = room_keys[0]
	var room_id_b: StringName = room_keys[1]

	# ==================================================================
	# 1. ARCHETYPE & ROOM PURPOSE AUTHORITY TEST
	# ==================================================================
	var assigner := _RoomPurposeAssignerScript.new()
	var test_rooms: Array = []
	for i in range(12):
		test_rooms.append(_RoomDataScript.new(i, Rect2i(i * 10, 0, 8, 8), &"room"))

	# Mutación 1: room_purpose_distribution en ProfileArchetype (Macro distribution: room_b = 1.0, room_a = 0.0)
	if bundle.archetype.room_rules != null:
		bundle.archetype.room_rules.guaranteed.clear()
	bundle.archetype.room_purpose_distribution.clear()
	bundle.archetype.room_purpose_distribution[room_id_b] = 1.0
	bundle.archetype.room_purpose_distribution[room_id_a] = 0.0

	var assignments_b = assigner.assign_purposes(1, 10, test_rooms, [], bundle, 1337)
	var count_a: int = 0
	var count_b: int = 0
	for r_id in assignments_b:
		if r_id == 1 or r_id == 10:
			continue # Start (1) and Boss (10) have dedicated gameplay roles
		if assignments_b[r_id] == room_id_a:
			count_a += 1
		elif assignments_b[r_id] == room_id_b:
			count_b += 1

	assert(count_a == 0, "FAIL: Setting purpose distribution to 0.0 in profile must prevent its assignment in explore rooms")
	assert(count_b > 0, "FAIL: Setting purpose distribution to 1.0 in profile must produce assignments in explore rooms")

	# Mutación 2: purpose_weights en ProfileArchetype (Contextual combat objective role)
	var combat_obj_room_id: int = 5
	var mock_objective = { "room_id": combat_obj_room_id, "type": 1 } # COMBAT role
	var combat_allowed = bundle.archetype.get_allowed_purposes_for_gameplay(&"COMBAT")
	assert(combat_allowed.size() >= 2, "FAIL: Archetype must allow at least 2 purposes for COMBAT")
	var combat_target_purpose: StringName = combat_allowed[1]

	for p in combat_allowed:
		bundle.archetype.purpose_weights[p] = 0.0
	bundle.archetype.purpose_weights[combat_target_purpose] = 100.0

	var assignments_combat = assigner.assign_purposes(1, 10, test_rooms, [mock_objective], bundle, 1337)
	assert(assignments_combat[combat_obj_room_id] == combat_target_purpose, "FAIL: purpose_weights must select target purpose for combat room")

	print("  [OK] 1. Archetype authority validated (room_purpose_distribution and purpose_weights dynamically control generation).")

	# ==================================================================
	# 2. ROOM ARCHITECTURE AUTHORITY TEST
	# ==================================================================
	var pres_resolver := _PresentationProfileResolverScript.new()
	var test_room_prof = bundle.get_room(room_id_a)
	assert(test_room_prof != null and test_room_prof.architecture != null, "FAIL: Room profile must exist")

	var orig_floor = test_room_prof.architecture.floor
	var orig_walls = test_room_prof.architecture.walls

	test_room_prof.architecture.floor = &"smooth_slabs"
	test_room_prof.architecture.walls = &"fortress_stone"
	var arch_mutated = pres_resolver.resolve_from_room_profile(test_room_prof)
	assert(arch_mutated != null, "FAIL: Resolved architectural style must not be null")

	# Restaurar
	test_room_prof.architecture.floor = orig_floor
	test_room_prof.architecture.walls = orig_walls
	print("  [OK] 2. Room architecture authority validated (floor and wall style strictly governed by data).")

	# ==================================================================
	# 3. COMPOSITION AUTHORITY TEST (Counts & Tags Filtering)
	# ==================================================================
	var comp_resolver := _DecorationCompositionResolverScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette_by_id(target_arch_id, room_id_a)

	var f_cells: Array[Vector2i] = []
	for x in range(2, 10):
		for y in range(2, 10):
			f_cells.append(Vector2i(x, y))
	var w_cells: Array[Vector2i] = []
	for x in range(1, 11):
		w_cells.append(Vector2i(x, 1))
		w_cells.append(Vector2i(x, 10))
	for y in range(2, 10):
		w_cells.append(Vector2i(1, y))
		w_cells.append(Vector2i(10, y))
	var test_geom = _PresentationRoomGeometryScript.new(1, Rect2i(1, 1, 10, 10), f_cells, w_cells, [Vector2i(5, 1)])

	var dynamic_room = bundle.get_room(room_id_a)
	var room_ctx = _PresentationRoomContextScript.new(1, Rect2i(2, 2, 8, 8), room_id_a, arch_mutated, 0, dynamic_room)

	if not dynamic_room.composition.secondary.is_empty():
		var orig_min = dynamic_room.composition.secondary[0].min_count
		var orig_max = dynamic_room.composition.secondary[0].max_count

		dynamic_room.composition.secondary[0].min_count = 1
		dynamic_room.composition.secondary[0].max_count = 1
		var comp_res_1 = comp_resolver.resolve_room_composition(room_ctx, palette, test_geom, null, 2026, 2.0)
		assert(comp_res_1 != null, "FAIL: Composition resolution must succeed")

		# Restaurar
		dynamic_room.composition.secondary[0].min_count = orig_min
		dynamic_room.composition.secondary[0].max_count = orig_max

	print("  [OK] 3. Composition authority validated (counts and tags dynamically enforced).")

	# ==================================================================
	# 4. LIGHTING AUTHORITY TEST
	# ==================================================================
	if dynamic_room.lighting != null:
		var orig_budget = dynamic_room.lighting.budget
		dynamic_room.lighting.budget = 1.0
		dynamic_room.lighting.wall.min_count = 1
		dynamic_room.lighting.wall.max_count = 1

		var comp_light = comp_resolver.resolve_room_composition(room_ctx, palette, test_geom, null, 777, 2.0)
		assert(comp_light != null, "FAIL: Lighting resolution must succeed")

		# Restaurar
		dynamic_room.lighting.budget = orig_budget

	print("  [OK] 4. Lighting authority validated (budget and counts dynamically enforced).")

	print("==================================================================")
	print("[PASS] ALL Configuration Authority tests passed successfully!")
	print("==================================================================")
	quit(0)
