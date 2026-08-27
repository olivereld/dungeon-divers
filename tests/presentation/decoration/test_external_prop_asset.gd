extends SceneTree

const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_external_prop_asset ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var provider := _PropAssetProviderScript.new()
	loader.populate_prop_asset_registry(provider.get_registry())

	var node = provider.materialize_by_id(&"pillar_stone")
	assert(node != null, "FAIL: Failed to materialize pillar_stone")
	assert(node is Node3D, "FAIL: Materialized prop must be Node3D")
	assert(node.get_child_count() > 0, "FAIL: Node3D must have children (mesh/collision)")
	
	node.free()
	print("  [OK] pillar_stone successfully materialized from external 3D scene.")
	print("==================================================================")
	print("[PASS] test_external_prop_asset completed successfully!")
	print("==================================================================")
	quit(0)
