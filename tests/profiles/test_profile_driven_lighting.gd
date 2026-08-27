extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")
const _ProfileLightSettingsScript = preload("res://src/dungeon_generator/profiles/profile_light_settings.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_profile_driven_lighting ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var validator := _ProfileValidatorScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: bundle must load")

	var v_res = validator.validate(bundle)
	assert(v_res.is_valid, "FAIL: bundle must pass validation: %s" % str(v_res.errors))

	# ==================================================================
	# 1. PARSING & DEFAULTS
	# ==================================================================
	var tomb_prof = bundle.get_room(&"tomb")
	assert(tomb_prof != null, "FAIL: tomb room profile must exist")
	assert(tomb_prof.lighting != null, "FAIL: tomb lighting must not be null")
	assert(tomb_prof.lighting.defaults != null, "FAIL: tomb lighting defaults must not be null")
	assert(tomb_prof.lighting.defaults.has_color(), "FAIL: tomb lighting defaults must have color")
	assert(tomb_prof.lighting.defaults.has_energy(), "FAIL: tomb lighting defaults must have energy")
	assert(tomb_prof.lighting.defaults.has_range(), "FAIL: tomb lighting defaults must have range")

	print("  [OK] 1. ProfileLightSettings contract & JSON parsing verified.")

	# ==================================================================
	# 2. HIERARCHY RESOLUTION (Asset > Fixture Slot > Room Default > Fallback)
	# ==================================================================
	var prof_light = bundle.get_room(&"tomb").lighting

	# 2.1 Fallback / Room Default
	var res_default = prof_light.resolve_settings_for_fixture(&"wall", &"wall_torch", Color.WHITE, 0.8, 3.0)
	assert(res_default.color == prof_light.defaults.color, "FAIL: Should resolve to room default color")
	assert(res_default.energy == prof_light.defaults.energy, "FAIL: Should resolve to room default energy")

	# 2.2 Fixture Slot Override
	prof_light.wall.lighting_override = _ProfileLightSettingsScript.new(Color(1, 0, 0, 1), 2.0, 6.0) # Rojo
	var res_slot = prof_light.resolve_settings_for_fixture(&"wall", &"wall_torch", Color.WHITE, 0.8, 3.0)
	assert(res_slot.color == Color(1, 0, 0, 1), "FAIL: Slot override must supersede room default color")
	assert(res_slot.energy == 2.0, "FAIL: Slot override must supersede room default energy")

	# 2.3 Asset-Specific Override
	prof_light.wall.asset_overrides[&"wall_torch"] = _ProfileLightSettingsScript.new(Color(0, 1, 0, 1), -1.0, -1.0) # Verde, hereda energy y range del slot
	var res_asset = prof_light.resolve_settings_for_fixture(&"wall", &"wall_torch", Color.WHITE, 0.8, 3.0)
	assert(res_asset.color == Color(0, 1, 0, 1), "FAIL: Asset override must supersede slot override color")
	assert(res_asset.energy == 2.0, "FAIL: Asset override must inherit slot override energy when -1")
	assert(res_asset.light_range == 6.0, "FAIL: Asset override must inherit slot override range when -1")

	# Limpiar overrides de test
	prof_light.wall.lighting_override = null
	prof_light.wall.asset_overrides.clear()

	print("  [OK] 2. Hierarchy resolution (Asset > Slot > Room > Fallback) strictly verified.")

	# ==================================================================
	# 3. VALIDATOR CONSTRAINTS
	# ==================================================================
	var invalid_slot := _ProfileLoaderScript.new()._parse_lighting_slot({
		"min": 1,
		"max": 2,
		"allowed": ["wall_torch"],
		"lighting_override": {
			"energy": -5.0,
			"range": -1.0
		}
	})
	prof_light.wall = invalid_slot
	var v_invalid = validator.validate(bundle)
	assert(not v_invalid.is_valid, "FAIL: Validator must reject negative energy and negative range")
	# Restaurar slot válido
	prof_light.wall = _ProfileLoaderScript.new()._parse_lighting_slot({
		"min": 1, "max": 2, "allowed": ["wall_torch"]
	})

	print("  [OK] 3. ProfileValidator lighting constraints verified.")

	# ==================================================================
	# 4. END-TO-END DIRECTIVE GENERATION
	# ==================================================================
	var pres_resolver := _PresentationProfileResolverScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var comp_resolver := _DecorationCompositionResolverScript.new()

	var arch_prof = pres_resolver.resolve_from_room_profile(tomb_prof, _DungeonArchetypeScript.Type.MAUSOLEUM, int(_RoomPurposeScript.Type.TOMB))
	var pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, int(_RoomPurposeScript.Type.TOMB))
	var ctx = _PresentationRoomContextScript.new(1, Rect2i(1, 1, 8, 8), int(_RoomPurposeScript.Type.TOMB), arch_prof, 0, tomb_prof)

	var floor_cells: Array[Vector2i] = []
	for x in range(2, 8):
		for y in range(2, 8):
			floor_cells.append(Vector2i(x, y))
	var geom = _PresentationRoomGeometryScript.new(1, Rect2i(1, 1, 8, 8), floor_cells, [], [Vector2i(4, 1)])

	# Configurar color púrpura en room defaults del JSON
	tomb_prof.lighting.defaults.color = Color(0.8, 0.2, 0.9, 1.0)
	tomb_prof.lighting.defaults.energy = 1.75
	tomb_prof.lighting.defaults.light_range = 5.5

	var comp = comp_resolver.resolve_room_composition(ctx, pal, geom, null, 1234, 2.0)
	assert(not comp.fixture_directives.is_empty(), "FAIL: Fixtures must be placed")

	for f_dir in comp.fixture_directives:
		assert(f_dir.has_custom_lighting, "FAIL: FixtureDirective must have custom lighting set by profile")
		assert(f_dir.get_effective_color() == Color(0.8, 0.2, 0.9, 1.0), "FAIL: Effective color must match profile (%s vs %s)" % [str(f_dir.get_effective_color()), str(Color(0.8, 0.2, 0.9, 1.0))])
		assert(f_dir.get_effective_energy() == 1.75, "FAIL: Effective energy must match profile (%f vs 1.75)" % f_dir.get_effective_energy())
		assert(f_dir.get_effective_range() == 5.5, "FAIL: Effective range must match profile (%f vs 5.5)" % f_dir.get_effective_range())

	print("  [OK] 4. End-to-end FixtureDirective lighting resolution verified.")

	print("==================================================================")
	print("[PASS] ALL Profile-Driven Lighting tests passed successfully!")
	print("==================================================================")
	quit(0)
