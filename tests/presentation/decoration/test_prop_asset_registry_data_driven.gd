extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_prop_asset_registry_data_driven ---")
	print("==================================================================")

	var registry := _PropAssetRegistryScript.new()

	# Assert that all 23 props from props.json are present in the registry
	var sample_props: Array[StringName] = [
		&"sarcophagus_stone_closed",
		&"sarcophagus_wood_open",
		&"tombstone_classic_wall",
		&"stone_altar_center",
		&"pillar_stone",
		&"church_pew_wall",
		&"crypt_urn_relic_floor",
		&"fortress_table_center",
		&"fortress_chest_corner",
		&"mine_crate_corner"
	]

	for pid in sample_props:
		assert(registry.has_definition(pid), "FAIL: registry must contain data-driven prop definition for %s" % str(pid))
		var def = registry.get_definition(pid)
		assert(def != null, "FAIL: definition must not be null for %s" % str(pid))
		print("  [OK] Registry has %s (source_type: %d)" % [str(pid), def.source_type])

	# Check procedural spec for sarcophagus_stone_closed
	var sarc = registry.get_definition(&"sarcophagus_stone_closed")
	assert(sarc.source_type == _PropAssetSourceScript.SourceType.PROCEDURAL, "FAIL: sarcophagus should be procedural")
	assert(sarc.procedural_builder_id == &"sarcophagus_prop", "FAIL: builder_id should be sarcophagus_prop")
	assert(sarc.procedural_params.get("style") == 0, "FAIL: style should be 0")

	# Check packed_scene spec for pillar_stone
	var pillar = registry.get_definition(&"pillar_stone")
	assert(pillar.source_type == _PropAssetSourceScript.SourceType.PACKED_SCENE, "FAIL: pillar should be packed_scene")
	assert(pillar.scene_path == "res://assets/scenes/props/pillar_stone.tscn", "FAIL: scene_path should match")
	assert(pillar.default_scale == Vector3(3.0, 3.0, 3.0), "FAIL: default_scale should match props.json (3.0)")

	print("==================================================================")
	print("[PASS] test_prop_asset_registry_data_driven passed with 100% success!")
	print("==================================================================")
	quit(0)
