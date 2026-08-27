extends SceneTree

const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_prop_scale_authority ---")
	print("==================================================================")

	var registry := _PropAssetRegistryScript.new()
	var loader := _ProfileLoaderScript.new()
	loader.populate_prop_asset_registry(registry)

	var def = registry.get_definition(&"pillar_stone")
	assert(def != null, "FAIL: pillar_stone definition must exist in registry")
	print("  pillar_stone definition default_scale from props.json: ", def.default_scale)

	var provider := _PropAssetProviderScript.new()
	provider.set_registry(registry)

	var spawner := _PropSpawnerScript.new(provider)

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 14, null)

	var pillar_style = null
	for entry in palette.props.entries:
		if entry.style.id == &"pillar_stone":
			pillar_style = entry.style
			break

	assert(pillar_style != null, "FAIL: pillar_style must exist in palette")

	var directive := _PropDirectiveScript.new(
		&"pillar_stone",
		1,
		pillar_style,
		Vector3.ZERO,
		0.0,
		[Vector2i.ZERO],
		0,
		0
	)

	var root := Node3D.new()
	var spawned = spawner.spawn_prop(directive, root)
	assert(spawned != null, "FAIL: spawned node is null")

	print("  Spawned pillar node.scale: ", spawned.scale)
	assert(spawned.scale.is_equal_approx(def.default_scale), "FAIL: Spawned node scale (%s) must match definition default_scale (%s)" % [str(spawned.scale), str(def.default_scale)])

	print("==================================================================")
	print("[PASS] test_prop_scale_authority passed successfully!")
	print("==================================================================")
	quit(0)
