extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_profile_loader ---")

	var loader := _ProfileLoaderScript.new()

	# 1. Load Asset Registry
	var assets = loader.load_asset_registry()
	assert(assets != null, "FAIL: AssetRegistry should not be null")
	assert(assets.props.size() >= 12, "FAIL: Should load at least 12 props, found %d" % assets.props.size())
	assert(assets.fixtures.size() >= 6, "FAIL: Should load at least 6 fixtures, found %d" % assets.fixtures.size())
	assert(assets.materials.size() >= 3, "FAIL: Should load at least 3 materials, found %d" % assets.materials.size())
	assert(assets.has_prop(&"sarcophagus_stone_closed"), "FAIL: Missing sarcophagus_stone_closed")
	assert(assets.has_fixture(&"wall_torch"), "FAIL: Missing wall_torch")
	assert(assets.has_material(&"mausoleum_stone"), "FAIL: Missing mausoleum_stone")

	# 2. Load Archetype
	var arch = loader.load_archetype("mausoleum")
	assert(arch != null, "FAIL: Archetype mausoleum should not be null")
	assert(arch.id == &"mausoleum", "FAIL: Archetype ID mismatch")
	assert(arch.schema_version == 1, "FAIL: Schema version mismatch")
	assert(arch.rooms.size() == 9, "FAIL: Mausoleum should reference 9 rooms, found %d" % arch.rooms.size())
	assert(arch.purpose_weights.has(&"crypt"), "FAIL: Missing crypt weight")
	assert(arch.gameplay_purpose_map.has(&"BOSS"), "FAIL: Missing BOSS gameplay map")

	# 3. Load Room
	var tomb_room = loader.load_room("tomb.json")
	assert(tomb_room != null, "FAIL: Room tomb.json should load successfully")
	assert(tomb_room.id == &"tomb", "FAIL: Room ID mismatch")
	assert(tomb_room.schema_version == 1, "FAIL: Room schema version mismatch")
	assert(tomb_room.intent != null, "FAIL: Room intent should not be null")
	assert(tomb_room.intent.type == &"burial", "FAIL: Room intent type mismatch")
	assert(tomb_room.composition != null, "FAIL: Room composition should not be null")
	assert(tomb_room.composition.primary != null, "FAIL: Room primary rule should exist")
	assert(tomb_room.lighting != null, "FAIL: Room lighting should not be null")
	assert(tomb_room.relationships.size() >= 2, "FAIL: Room relationships should load")

	# 4. Load Full Bundle
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null, "FAIL: ProfileBundle should not be null")
	assert(bundle.archetype != null, "FAIL: Bundle archetype should not be null")
	assert(bundle.rooms.size() == 9, "FAIL: Bundle should contain 9 loaded rooms, found %d" % bundle.rooms.size())
	assert(bundle.has_room(&"tomb"), "FAIL: Bundle missing room tomb")
	assert(bundle.has_room(&"entrance"), "FAIL: Bundle missing room entrance")
	assert(bundle.has_room(&"sacristy"), "FAIL: Bundle missing room sacristy")

	print("[PASS] test_profile_loader completed successfully!")
	quit(0)
