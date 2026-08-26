extends SceneTree

const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")
const _AssetPropEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_prop_entry.gd")
const _AssetFixtureEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_fixture_entry.gd")
const _AssetMaterialEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_material_entry.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_asset_registry ---")

	var reg := _AssetRegistryScript.new()

	# 1. Props registration and queries
	var prop := _AssetPropEntryScript.new(
		&"test_sarcophagus",
		"res://test_scene.tscn",
		[&"burial", &"focal"],
		[&"center", &"floor"],
		Vector2i(2, 1),
		&"blocking",
		[&"floor"]
	)
	reg.register_prop(prop)

	assert(reg.has_prop(&"test_sarcophagus"), "FAIL: Registered prop should exist")
	assert(not reg.has_prop(&"unknown_prop"), "FAIL: Unknown prop should not exist")
	assert(reg.get_prop(&"test_sarcophagus") == prop, "FAIL: get_prop must return registered prop")

	var focal_props = reg.get_props_by_tag(&"focal")
	assert(focal_props.size() == 1, "FAIL: Should find 1 focal prop")
	assert(focal_props[0].id == &"test_sarcophagus", "FAIL: Found prop ID mismatch")

	# 2. Fixtures registration and queries
	var fixture := _AssetFixtureEntryScript.new(
		&"test_torch",
		"res://torch.tscn",
		&"torch",
		[&"wall"],
		[&"wall"],
		[&"lighting", &"wall_fixture"]
	)
	reg.register_fixture(fixture)

	assert(reg.has_fixture(&"test_torch"), "FAIL: Registered fixture should exist")
	assert(not reg.has_fixture(&"unknown_fixture"), "FAIL: Unknown fixture should not exist")
	assert(reg.get_fixtures_by_tag(&"lighting").size() == 1, "FAIL: Should find 1 lighting fixture")

	# 3. Materials registration
	var mat := _AssetMaterialEntryScript.new(
		&"test_stone",
		"res://floor.tres",
		"res://wall.tres",
		"res://trim.tres"
	)
	reg.register_material(mat)

	assert(reg.has_material(&"test_stone"), "FAIL: Registered material should exist")
	assert(reg.get_material(&"test_stone").wall_path == "res://wall.tres", "FAIL: Material property mismatch")

	print("[PASS] test_asset_registry completed successfully!")
	quit(0)
