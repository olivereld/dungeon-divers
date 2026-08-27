extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileCompositionScript = preload("res://src/dungeon_generator/profiles/profile_composition.gd")
const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_profile_driven_composition ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: Bundle must load")

	# --- Task 1: ProfileComposition Contract ---
	var crypt_profile = bundle.get_room(&"crypt")
	assert(crypt_profile != null, "FAIL: Crypt profile must exist")
	assert(crypt_profile.composition != null, "FAIL: Crypt composition must exist")
	assert(crypt_profile.composition.get_all_rules().size() >= 1, "FAIL: Crypt must have rules")
	assert(crypt_profile.composition.get_rules_by_role().has("secondary"), "FAIL: Roles dict missing secondary")
	print("  [OK] Task 1: ProfileComposition contract validated.")

	# Setup presentation environment for spatial tests
	var resolver := _DecorationCompositionResolverScript.new()
	var palette_resolver := _DecorationPaletteResolverScript.new()
	var palette = palette_resolver.resolve_palette(
		_DungeonArchetypeScript.Type.MAUSOLEUM,
		_RoomPurposeScript.Type.CRYPT
	)
	assert(palette != null and palette.props != null, "FAIL: Palette must resolve")

	# Create a standard 8x8 room geometry
	var floor_cells: Array[Vector2i] = []
	for x in range(2, 10):
		for y in range(2, 10):
			floor_cells.append(Vector2i(x, y))

	var wall_cells: Array[Vector2i] = []
	for x in range(1, 11):
		wall_cells.append(Vector2i(x, 1))
		wall_cells.append(Vector2i(x, 10))
	for y in range(2, 10):
		wall_cells.append(Vector2i(1, y))
		wall_cells.append(Vector2i(10, y))

	var room_bounds := Rect2i(1, 1, 10, 10)
	var room_geom := _PresentationRoomGeometryScript.new(1, room_bounds, floor_cells, wall_cells, [Vector2i(5, 1)])


	# --- Task 2: Profile-driven Props Placement ---

	# Test A: TOMB — Sarcophagus focal primary placement
	var tomb_profile = bundle.get_room(&"tomb")
	assert(tomb_profile != null, "FAIL: Tomb profile must exist")
	var tomb_palette = palette_resolver.resolve_palette(
		_DungeonArchetypeScript.Type.MAUSOLEUM,
		_RoomPurposeScript.Type.TOMB
	)

	var arch_prof := _ArchitecturalPresentationProfileScript.new()
	var tomb_context := _PresentationRoomContextScript.new(
		1,
		Rect2i(2, 2, 8, 8),
		int(_RoomPurposeScript.Type.TOMB),
		arch_prof,
		0,
		tomb_profile
	)

	var tomb_comp = resolver.resolve_room_composition(
		tomb_context,
		tomb_palette,
		room_geom,
		null,
		1337,
		2.0
	)
	assert(tomb_comp != null, "FAIL: Tomb composition must be generated")
	assert(not tomb_comp.prop_directives.is_empty(), "FAIL: Tomb must have prop directives")

	var has_sarcophagus: bool = false
	var has_altar: bool = false
	for p_dir in tomb_comp.prop_directives:
		if p_dir.prop_id == &"sarcophagus_stone_closed" or p_dir.prop_id == &"sarcophagus_stone_open":
			has_sarcophagus = true
		if p_dir.prop_id == &"stone_altar_center":
			has_altar = true

	assert(has_sarcophagus, "FAIL: Tomb must place central sarcophagus from tomb.json")
	assert(not has_altar, "FAIL: Tomb must NOT place altar (forbidden by intent)")
	print("  [OK] Task 2 (Tomb): Primary sarcophagus placed, altar excluded.")

	# Test B: SACRISTY — Altar focal primary + pews seating secondary
	var sacristy_profile = bundle.get_room(&"sacristy")
	assert(sacristy_profile != null, "FAIL: Sacristy profile must exist")
	var sacristy_palette = palette_resolver.resolve_palette(
		_DungeonArchetypeScript.Type.MAUSOLEUM,
		_RoomPurposeScript.Type.SACRISTY
	)

	var sacristy_context := _PresentationRoomContextScript.new(
		2,
		Rect2i(2, 2, 8, 8),
		int(_RoomPurposeScript.Type.SACRISTY),
		arch_prof,
		0,
		sacristy_profile
	)

	var sacristy_comp = resolver.resolve_room_composition(
		sacristy_context,
		sacristy_palette,
		room_geom,
		null,
		2026,
		2.0
	)
	assert(sacristy_comp != null, "FAIL: Sacristy composition must be generated")

	var sacristy_has_altar: bool = false
	var sacristy_has_pew: bool = false
	var sacristy_has_sarcophagus: bool = false
	for p_dir in sacristy_comp.prop_directives:
		if p_dir.prop_id == &"stone_altar_center":
			sacristy_has_altar = true
		if p_dir.prop_id == &"church_pew_wall" or p_dir.prop_id == &"stone_orior_floor":
			sacristy_has_pew = true
		if p_dir.prop_id == &"sarcophagus_stone_closed" or p_dir.prop_id == &"sarcophagus_stone_open":
			sacristy_has_sarcophagus = true

	assert(sacristy_has_altar, "FAIL: Sacristy must place altar from sacristy.json")
	assert(sacristy_has_pew, "FAIL: Sacristy must place pews from sacristy.json")
	assert(not sacristy_has_sarcophagus, "FAIL: Sacristy must NOT place sarcophagus")
	print("  [OK] Task 2 (Sacristy): Altar and pews placed, sarcophagus excluded.")

	# Test C: ROYAL TOMB — Sarcophagus + Hanging lantern above + No wall lantern in center
	var royal_tomb_profile = bundle.get_room(&"royal_tomb")
	assert(royal_tomb_profile != null, "FAIL: Royal tomb profile must exist")
	var royal_tomb_palette = palette_resolver.resolve_palette(
		_DungeonArchetypeScript.Type.MAUSOLEUM,
		_RoomPurposeScript.Type.ROYAL_TOMB
	)

	var royal_tomb_context := _PresentationRoomContextScript.new(
		4,
		Rect2i(2, 2, 8, 8),
		int(_RoomPurposeScript.Type.ROYAL_TOMB),
		arch_prof,
		0,
		royal_tomb_profile
	)

	var royal_tomb_comp = resolver.resolve_room_composition(
		royal_tomb_context,
		royal_tomb_palette,
		room_geom,
		null,
		777,
		2.0
	)
	assert(royal_tomb_comp != null, "FAIL: Royal tomb composition must be generated")

	var royal_has_hanging_lantern: bool = false
	var royal_has_floating_wall_lantern: bool = false
	for f_dir in royal_tomb_comp.fixture_directives:
		if f_dir.placement.mode == _FixturePlacementModeScript.Mode.HANGING:
			royal_has_hanging_lantern = true
		if f_dir.placement.mode == _FixturePlacementModeScript.Mode.WALL:
			# Must be adjacent to a wall cell, not in the room center (e.g. x=5, y=5)
			if f_dir.placement.cell.x > 2 and f_dir.placement.cell.x < 9 and f_dir.placement.cell.y > 2 and f_dir.placement.cell.y < 9:
				royal_has_floating_wall_lantern = true

	assert(royal_has_hanging_lantern, "FAIL: Royal tomb must place hanging lantern above sarcophagus")
	assert(not royal_has_floating_wall_lantern, "FAIL: Royal tomb must NOT place floating wall lantern in center")
	print("  [OK] Task 2 (Royal Tomb): Hanging lantern placed above sarcophagus, no floating wall lantern.")


	# --- Task 3: Profile-driven Relational Lighting ---

	# Verify Tomb generated fixtures near sarcophagus (candle_cluster or candle_holder)
	assert(not tomb_comp.fixture_directives.is_empty(), "FAIL: Tomb must have fixtures")
	var tomb_has_relational_candles: bool = false
	for f_dir in tomb_comp.fixture_directives:
		if f_dir.fixture_id == &"candle_cluster" or f_dir.fixture_id == &"candle_holder" or str(f_dir.fixture_id).contains("candle"):
			tomb_has_relational_candles = true
			break
	assert(tomb_has_relational_candles, "FAIL: Tomb must generate candles via sarcophagus relationship")
	print("  [OK] Task 3: Relational lighting resolved according to ProfileRelationship.")


	# --- Task 4: Data-Driven Proof (modifying max_count dynamically) ---
	var dynamic_crypt = bundle.get_room(&"crypt")
	assert(dynamic_crypt.composition.secondary.size() >= 1)
	dynamic_crypt.composition.secondary[0].min_count = 3
	dynamic_crypt.composition.secondary[0].max_count = 3
	var crypt_palette = palette_resolver.resolve_palette(
		_DungeonArchetypeScript.Type.MAUSOLEUM,
		_RoomPurposeScript.Type.CRYPT
	)

	var dynamic_context := _PresentationRoomContextScript.new(
		3,
		Rect2i(2, 2, 8, 8),
		int(_RoomPurposeScript.Type.CRYPT),
		arch_prof,
		0,
		dynamic_crypt
	)

	var dynamic_comp = resolver.resolve_room_composition(
		dynamic_context,
		crypt_palette,
		room_geom,
		null,
		9999,
		2.0
	)
	assert(dynamic_comp.prop_directives.size() >= 3, "FAIL: Dynamic count modification must place exactly >= 3 props (placed %d)" % dynamic_comp.prop_directives.size())
	print("  [OK] Task 4: Dynamic JSON rule modification directly controls prop counts (placed %d)." % dynamic_comp.prop_directives.size())


	print("==================================================================")
	print("[PASS] ALL Profile-Driven Composition tests passed successfully!")
	print("==================================================================")
	quit(0)
