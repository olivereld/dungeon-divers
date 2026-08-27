extends SceneTree

## Suite exhaustiva de verificación de Autoridad de Configuración.
## Demuestra que los archivos JSON (Archetypes, Rooms, Assets) son la única fuente
## de verdad y que mutar sus datos altera la generación, arquitectura, composición,
## iluminación y relaciones sin modificar GDScript.

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
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
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null and bundle.archetype != null, "FAIL: Mausoleum bundle must load")

	# ==================================================================
	# 1. ARCHETYPE & ROOM PURPOSE AUTHORITY TEST
	# ==================================================================
	var assigner := _RoomPurposeAssignerScript.new()
	var test_rooms: Array = []
	for i in range(12):
		test_rooms.append(_RoomDataScript.new(i, Rect2i(i * 10, 0, 8, 8), &"room"))

	# Baseline: Mausoleum por defecto (asigna Crypt con peso macro y contextual)
	var assignments_default = assigner.assign_purposes(1, 10, test_rooms, [], bundle, 1337)
	var crypt_count_a: int = 0
	for r_id in assignments_default:
		if assignments_default[r_id] == _RoomPurposeScript.Type.CRYPT:
			crypt_count_a += 1

	# Mutación 1: room_purpose_distribution en ProfileArchetype (Macro distribution: Tomb = 1.0, Crypt = 0.0)
	bundle.archetype.room_purpose_distribution[&"tomb"] = 1.0
	bundle.archetype.room_purpose_distribution[&"crypt"] = 0.0
	bundle.archetype.room_purpose_distribution[&"catacomb"] = 0.0
	bundle.archetype.room_purpose_distribution[&"hall"] = 0.0
	bundle.archetype.room_purpose_distribution[&"chamber"] = 0.0

	var assignments_modified_macro = assigner.assign_purposes(1, 10, test_rooms, [], bundle, 1337)
	var crypt_count_b: int = 0
	var tomb_count_b: int = 0
	for r_id in assignments_modified_macro:
		if assignments_modified_macro[r_id] == _RoomPurposeScript.Type.CRYPT:
			crypt_count_b += 1
		elif assignments_modified_macro[r_id] == _RoomPurposeScript.Type.TOMB:
			tomb_count_b += 1

	assert(crypt_count_a > 0, "FAIL: Default mausoleum must assign crypts")
	assert(crypt_count_b == 0, "FAIL: Setting crypt distribution to 0.0 in profile must prevent crypt explore assignments")
	assert(tomb_count_b > 0, "FAIL: Elevating tomb distribution in profile must produce tomb assignments")

	# Mutación 2: purpose_weights en ProfileArchetype (Contextual combat objective role)
	var combat_obj_room_id: int = 5
	var mock_objective = { "room_id": combat_obj_room_id, "type": 1 } # COMBAT role
	bundle.archetype.purpose_weights[&"crypt"] = 0.0
	bundle.archetype.purpose_weights[&"catacomb"] = 100.0
	var assignments_combat = assigner.assign_purposes(1, 10, test_rooms, [mock_objective], bundle, 1337)
	assert(assignments_combat[combat_obj_room_id] == _RoomPurposeScript.Type.CATACOMB, "FAIL: purpose_weights must select CATACOMB for combat room when crypt weight is 0.0")

	print("  [OK] 1. Archetype authority validated (room_purpose_distribution and purpose_weights dynamically control generation).")

	# ==================================================================
	# 2. ROOM ARCHITECTURE AUTHORITY TEST
	# ==================================================================
	var pres_resolver := _PresentationProfileResolverScript.new()
	var crypt_room = bundle.get_room(&"crypt")
	assert(crypt_room != null and crypt_room.architecture != null, "FAIL: Crypt room profile must exist")

	# Baseline Crypt: floor=ruined_stone, walls=dark_stone, door=stone_arch, stairs=stone
	var arch_baseline = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_baseline.floor_style == _ArchitecturalStyleScript.FloorStyle.RUINED_STONE, "FAIL: Baseline floor must be RUINED_STONE")
	assert(arch_baseline.wall_style == _ArchitecturalStyleScript.WallStyle.DARK_STONE, "FAIL: Baseline wall must be DARK_STONE")
	assert(arch_baseline.door_style == _ArchitecturalStyleScript.DoorStyle.STONE_ARCH, "FAIL: Baseline door must be STONE_ARCH")
	assert(arch_baseline.stairs_style == _ArchitecturalStyleScript.StairsStyle.STONE, "FAIL: Baseline stairs must be STONE")

	# Mutación JSON 1: Suelo a smooth_slabs, Muros a fortress_stone, Puerta a iron_gate, Escaleras a wood
	crypt_room.architecture.floor = &"smooth_slabs"
	crypt_room.architecture.walls = &"fortress_stone"
	crypt_room.architecture.door = &"iron_gate"
	crypt_room.architecture.stairs = &"wood"

	var arch_mutated_1 = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_mutated_1.floor_style == _ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS, "FAIL: JSON mutation must yield SMOOTH_SLABS floor")
	assert(arch_mutated_1.wall_style == _ArchitecturalStyleScript.WallStyle.FORTRESS_STONE, "FAIL: JSON mutation must yield FORTRESS_STONE wall")
	assert(arch_mutated_1.door_style == _ArchitecturalStyleScript.DoorStyle.HEAVY_IRON, "FAIL: JSON mutation must yield HEAVY_IRON door")
	assert(arch_mutated_1.stairs_style == _ArchitecturalStyleScript.StairsStyle.WOOD, "FAIL: JSON mutation must yield WOOD stairs")

	# Mutación JSON 2: Suelo a catacomb_dirt
	crypt_room.architecture.floor = &"catacomb_dirt"
	var arch_mutated_2 = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_mutated_2.floor_style == _ArchitecturalStyleScript.FloorStyle.CATACOMB_DIRT, "FAIL: JSON mutation must yield CATACOMB_DIRT floor")

	# Restaurar valores originales
	crypt_room.architecture.floor = &"ruined_stone"
	crypt_room.architecture.walls = &"dark_stone"
	crypt_room.architecture.door = &"stone_arch"
	crypt_room.architecture.stairs = &"stone"
	print("  [OK] 2. Room architecture authority validated (floor, walls, door, stairs strictly governed by JSON).")

	# ==================================================================
	# 3. COMPOSITION AUTHORITY TEST (Counts & Tags Filtering)
	# ==================================================================
	var comp_resolver := _DecorationCompositionResolverScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var crypt_palette = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, int(_RoomPurposeScript.Type.CRYPT))

	# Geometría estándar 10x10 para pruebas
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

	var dynamic_crypt = bundle.get_room(&"crypt")
	var crypt_ctx = _PresentationRoomContextScript.new(1, Rect2i(2, 2, 8, 8), int(_RoomPurposeScript.Type.CRYPT), arch_baseline, 0, dynamic_crypt)

	# Prueba A: min_count = 1, max_count = 1 en secundarias de crypt
	dynamic_crypt.composition.secondary[0].min_count = 1
	dynamic_crypt.composition.secondary[0].max_count = 1

	var comp_result_1 = comp_resolver.resolve_room_composition(crypt_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	assert(comp_result_1.prop_directives.size() == 1, "FAIL: max_count: 1 in JSON must produce exactly 1 prop, got %d" % comp_result_1.prop_directives.size())

	# Prueba B: min_count = 3, max_count = 3 en secundarias de crypt
	dynamic_crypt.composition.secondary[0].min_count = 3
	dynamic_crypt.composition.secondary[0].max_count = 3
	var comp_result_3 = comp_resolver.resolve_room_composition(crypt_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	assert(comp_result_3.prop_directives.size() == 3, "FAIL: max_count: 3 in JSON must produce 3 props, got %d" % comp_result_3.prop_directives.size())

	# Prueba C: forbidden_tags excluye completamente los props de entierro
	dynamic_crypt.composition.secondary[0].forbidden_tags.append(&"burial")
	var comp_result_forbidden = comp_resolver.resolve_room_composition(crypt_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	assert(comp_result_forbidden.prop_directives.size() == 0, "FAIL: Adding burial to forbidden_tags in JSON must completely forbid props")

	# Restaurar
	dynamic_crypt.composition.secondary[0].forbidden_tags.erase(&"burial")
	dynamic_crypt.composition.secondary[0].min_count = 0
	dynamic_crypt.composition.secondary[0].max_count = 4
	print("  [OK] 3. Composition authority validated (counts, asset_tags and forbidden_tags strictly enforced).")

	# ==================================================================
	# 4. LIGHTING & RELATIONSHIP AUTHORITY TEST
	# ==================================================================
	var tomb_room_prof = bundle.get_room(&"tomb")
	var tomb_palette = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, int(_RoomPurposeScript.Type.TOMB))
	var tomb_ctx = _PresentationRoomContextScript.new(2, Rect2i(2, 2, 8, 8), int(_RoomPurposeScript.Type.TOMB), arch_baseline, 0, tomb_room_prof)
	var saved_rels = tomb_room_prof.relationships.duplicate()

	# Prueba A: Presupuesto bajo (budget = 1.0) sin relaciones
	tomb_room_prof.relationships.clear()
	tomb_room_prof.lighting.budget = 1.0
	tomb_room_prof.lighting.wall.min_count = 1
	tomb_room_prof.lighting.wall.max_count = 1
	tomb_room_prof.lighting.floor.min_count = 0
	tomb_room_prof.lighting.floor.max_count = 0
	tomb_room_prof.lighting.hanging.min_count = 0
	tomb_room_prof.lighting.hanging.max_count = 0

	var comp_light_low = comp_resolver.resolve_room_composition(tomb_ctx, tomb_palette, test_geom, null, 777, 2.0)
	var fixtures_low_count = comp_light_low.fixture_directives.size()
	assert(fixtures_low_count == 1, "FAIL: Low budget (1.0) with min_count: 1 in JSON must produce exactly 1 fixture, got %d" % fixtures_low_count)

	# Presupuesto alto (budget = 6.0)
	tomb_room_prof.lighting.budget = 6.0
	tomb_room_prof.lighting.wall.min_count = 2
	tomb_room_prof.lighting.wall.max_count = 3
	tomb_room_prof.lighting.floor.min_count = 2
	tomb_room_prof.lighting.floor.max_count = 2
	var comp_light_high = comp_resolver.resolve_room_composition(tomb_ctx, tomb_palette, test_geom, null, 777, 2.0)
	var fixtures_high_count = comp_light_high.fixture_directives.size()
	assert(fixtures_high_count >= 4, "FAIL: High budget (6.0) in JSON must produce at least 4 fixtures (got %d)" % fixtures_high_count)

	# Prueba B: Relaciones prop-fixture gobernadas por JSON
	# Restaurar relationships -> deben generarse luminarias relacionales (source_type == 1)
	tomb_room_prof.relationships = saved_rels.duplicate()
	var comp_with_rels = comp_resolver.resolve_room_composition(tomb_ctx, tomb_palette, test_geom, null, 1337, 2.0)
	var has_rel_candle: bool = false
	for f in comp_with_rels.fixture_directives:
		if f.source_type == 1 or f.relation_id != &"":
			has_rel_candle = true
	assert(has_rel_candle, "FAIL: Restoring relationships in JSON must spawn relational companion fixtures")

	# Vaciar relationships -> 0 luminarias relacionales
	tomb_room_prof.relationships.clear()
	var comp_no_rels = comp_resolver.resolve_room_composition(tomb_ctx, tomb_palette, test_geom, null, 1337, 2.0)
	var has_rel_candle_no: bool = false
	for f in comp_no_rels.fixture_directives:
		if f.source_type == 1 or f.relation_id != &"":
			has_rel_candle_no = true
	assert(not has_rel_candle_no, "FAIL: Clearing relationships in JSON must completely prevent relational fixtures")

	# Restaurar original
	tomb_room_prof.relationships = saved_rels
	tomb_room_prof.lighting.budget = 4.0
	print("  [OK] 4. Lighting & Relationship authority validated (budget, slots and relations strictly enforced).")

	print("==================================================================")
	print("[PASS] ALL Configuration Authority tests passed successfully!")
	print("==================================================================")
	quit(0)
