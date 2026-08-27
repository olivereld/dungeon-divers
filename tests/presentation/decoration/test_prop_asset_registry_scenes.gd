extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_prop_asset_registry_scenes ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var registry := _PropAssetRegistryScript.new()
	
	loader.populate_prop_asset_registry(registry)
	assert(registry.has_definition(&"pillar_stone"), "FAIL: pillar_stone must be registered in PropAssetRegistry")
	
	var def = registry.get_definition(&"pillar_stone")
	assert(def.source_type == _PropAssetSourceScript.SourceType.PACKED_SCENE, "FAIL: source_type must be PACKED_SCENE")
	assert(def.scene_path != "" or def.scene != null, "FAIL: scene_path or scene must be populated")
	
	print("  [OK] PropAssetRegistry properly registers PACKED_SCENE from JSON.")
	print("==================================================================")
	print("[PASS] test_prop_asset_registry_scenes completed successfully!")
	print("==================================================================")
	quit(0)
