extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropAssetValidatorScript = preload("res://src/presentation/decoration/assets/prop_asset_validator.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_3d_model_variants_pipeline ---")
	print("==================================================================")

	var registry := _PropAssetRegistryScript.new()
	var validator := _PropAssetValidatorScript.new()

	var val_res = validator.validate_registry(registry)
	assert(val_res != null, "FAIL: validator must return result")
	print("  Validation errors: ", val_res.get("errors", []))
	assert(val_res.get("errors", []).is_empty(), "FAIL: registry must have 0 validation errors: %s" % str(val_res.get("errors", [])))

	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)

	# Verify variants resolution for pillar_stone
	var def = registry.get_definition(&"pillar_stone")
	assert(def != null, "FAIL: pillar_stone def must exist")

	var instantiated_scenes: Dictionary = {}
	for s in range(50):
		var node = provider.instantiate_with_seed(def, 1000 + s)
		assert(node != null, "FAIL: node must not be null")
		var var_id = node.get_meta("variant_id") if node.has_meta("variant_id") else "default"
		instantiated_scenes[var_id] = instantiated_scenes.get(var_id, 0) + 1
		node.free()

	print("  Variant distribution over 50 instantiations: ", instantiated_scenes)
	assert(instantiated_scenes.size() >= 2, "FAIL: Expected at least 2 variants instantiated for pillar_stone, got %d" % instantiated_scenes.size())

	print("==================================================================")
	print("[PASS] test_3d_model_variants_pipeline passed with 100% success!")
	print("==================================================================")
	quit(0)
