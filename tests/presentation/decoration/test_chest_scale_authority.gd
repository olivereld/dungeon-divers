extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_chest_scale_authority ---")
	print("==================================================================")

	var registry := _PropAssetRegistryScript.new()
	var def = registry.get_definition(&"chest_wooden")
	assert(def != null, "FAIL: chest_wooden def must exist")

	print("1. In PropAssetDefinition:")
	print("   default_scale: ", def.default_scale)

	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)

	var direct_node = provider.materialize_by_id(&"chest_wooden")
	print("2. Direct from PropAssetProvider:")
	print("   direct_node.scale: ", direct_node.scale)
	direct_node.free()

	var spawner := _PropSpawnerScript.new(provider)
	var style = _PropStyleScript.new(
		&"chest_wooden", _PropStyleScript.Type.CHEST,
		1, 1, null, &"chest_wooden", {}
	)
	var dir := _PropDirectiveScript.new(
		&"chest_wooden", 1, style, Vector3(5, 0, 5), 0.0, [Vector2i(2, 2)]
	)

	var parent := Node3D.new()
	var spawned_node = spawner.spawn_prop(dir, parent)
	print("3. From PropSpawner:")
	print("   spawned_node.scale: ", spawned_node.scale)

	parent.free()
	print("==================================================================")
	quit(0)
