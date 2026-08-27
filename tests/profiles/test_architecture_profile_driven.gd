extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_architecture_profile_driven ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var assets: _AssetRegistryScript = loader.load_asset_registry()
	assert(assets != null, "FAIL: AssetRegistry must load")
	assert(assets.has_architecture(&"catacomb_dirt"), "FAIL: catacomb_dirt must be in architecture catalog")
	assert(assets.has_architecture(&"dark_stone"), "FAIL: dark_stone must be in architecture catalog")
	assert(assets.has_architecture(&"stone_arch"), "FAIL: stone_arch must be in architecture catalog")
	print("  [OK] Task 1: Architecture catalog loaded into AssetRegistry.")

	# Validar Task 2: ProfileRoom.architecture
	var tomb_room = loader.load_room("tomb.json")
	assert(tomb_room != null, "FAIL: tomb.json must load")
	assert(tomb_room.architecture != null, "FAIL: tomb_room must have architecture object")
	assert(tomb_room.architecture.floor == &"catacomb_dirt", "FAIL: tomb floor must be catacomb_dirt")
	assert(tomb_room.architecture.walls == &"dark_stone", "FAIL: tomb walls must be dark_stone")
	assert(tomb_room.architecture.door == &"stone_arch", "FAIL: tomb door must be stone_arch")
	assert(tomb_room.architecture.stairs == &"stone", "FAIL: tomb stairs must be stone")
	print("  [OK] Task 2: ProfileRoom.architecture loaded properly.")

	# Validar Task 3: ProfileValidator
	var validator := preload("res://src/dungeon_generator/profiles/profile_validator.gd").new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: Bundle must load")
	var val_result = validator.validate(bundle)
	assert(val_result != null, "FAIL: Validation result must exist")
	assert(val_result.is_valid, "FAIL: Bundle validation errors: %s" % str(val_result.errors))

	# Negative test: invalid architecture floor must fail validation
	var bad_room = bundle.get_room(&"tomb")
	bad_room.architecture.floor = &"nonexistent_floor_style_xyz"
	var bad_val_result = validator.validate(bundle)
	assert(not bad_val_result.is_valid, "FAIL: Validation must fail for unknown architecture floor")
	bad_room.architecture.floor = &"catacomb_dirt" # Restore
	# Validar Task 4: All 9 room profiles have architecture blocks
	var expected_rooms: Array[String] = [
		"entrance", "hall", "chamber", "crypt", "catacomb", "tomb", "royal_tomb", "mortuary", "sacristy"
	]
	for r_name in expected_rooms:
		var r_prof = loader.load_room(r_name)
		assert(r_prof != null, "FAIL: Room '%s' must load" % r_name)
		assert(r_prof.architecture != null, "FAIL: Room '%s' must have architecture" % r_name)
		assert(r_prof.architecture.floor != &"", "FAIL: Room '%s' missing floor" % r_name)
		assert(r_prof.architecture.walls != &"", "FAIL: Room '%s' missing walls" % r_name)
		assert(r_prof.architecture.door != &"", "FAIL: Room '%s' missing door" % r_name)
		assert(r_prof.architecture.stairs != &"", "FAIL: Room '%s' missing stairs" % r_name)
		assert(assets.has_architecture(r_prof.architecture.floor), "FAIL: Room '%s' floor not in catalog" % r_name)
		assert(assets.has_architecture(r_prof.architecture.walls), "FAIL: Room '%s' walls not in catalog" % r_name)
		assert(assets.has_architecture(r_prof.architecture.door), "FAIL: Room '%s' door not in catalog" % r_name)
		assert(assets.has_architecture(r_prof.architecture.stairs), "FAIL: Room '%s' stairs not in catalog" % r_name)
	# Validar Task 5: PresentationProfileResolver integration & dynamic overrides
	var pres_resolver := preload("res://src/presentation/architecture/presentation_profile_resolver.gd").new()
	var arch_style := preload("res://src/presentation/architecture/architectural_style.gd")
	var room_purpose := preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
	var dungeon_archetype := preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

	var resolved_tomb = pres_resolver.resolve(
		dungeon_archetype.Type.MAUSOLEUM,
		room_purpose.Type.TOMB,
		tomb_room
	)
	assert(resolved_tomb != null, "FAIL: Resolved profile must exist")
	assert(resolved_tomb.floor_style == arch_style.FloorStyle.CATACOMB_DIRT, "FAIL: Resolved tomb floor must be CATACOMB_DIRT from tomb.json")
	assert(resolved_tomb.wall_style == arch_style.WallStyle.DARK_STONE, "FAIL: Resolved tomb wall must be DARK_STONE from tomb.json")

	# Dynamic JSON override test:
	tomb_room.architecture.floor = &"smooth_slabs"
	var overridden_tomb = pres_resolver.resolve(
		dungeon_archetype.Type.MAUSOLEUM,
		room_purpose.Type.TOMB,
		tomb_room
	)
	assert(overridden_tomb.floor_style == arch_style.FloorStyle.SMOOTH_SLABS, "FAIL: Overriding JSON floor must dynamically change resolved floor_style without GDScript edits")
	tomb_room.architecture.floor = &"catacomb_dirt" # Restore

	# Fallback test: when room_profile is null, legacy resolver operates seamlessly
	var fallback_tomb = pres_resolver.resolve(
		dungeon_archetype.Type.MAUSOLEUM,
		room_purpose.Type.TOMB,
		null
	)
	assert(fallback_tomb != null, "FAIL: Fallback profile must exist")
	assert(fallback_tomb.floor_style == arch_style.FloorStyle.CATACOMB_DIRT, "FAIL: Fallback tomb floor must be CATACOMB_DIRT")

	print("  [OK] Task 5: PresentationProfileResolver profile-driven resolution & dynamic overrides verified.")
	print("==================================================================")
	print("[PASS] ALL Architecture Profile Migration tests passed successfully!")
	print("==================================================================")
	quit(0)
