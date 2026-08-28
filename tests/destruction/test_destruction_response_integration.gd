extends SceneTree

const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_response_integration ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var response_service := _DestructionResponseServiceScript.new(provider)
	d_service.set_response_service(response_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	var parent := Node3D.new()
	var style := _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var directive := _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style, Vector3(5.0, 0.0, 5.0), 0.0, [Vector2i(2, 2)]
	)

	var urn_node = spawner.spawn_prop(directive, parent)
	assert(urn_node != null, "FAIL: prop must spawn")

	var comp: _DestructionCompScript = null
	for c in urn_node.get_children():
		if c is _DestructionCompScript:
			comp = c
			break
	assert(comp != null, "FAIL: DestructionComponent must be bound")

	# Fatal Hit
	comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))

	# Verifications:
	# 1. Original urn hidden
	assert(not urn_node.visible, "FAIL: original urn must be hidden")

	# 2. Debris / Effects / Replacement should have spawned into parent
	print("   Hijos resultantes en parent tras destrucción: %d" % parent.get_child_count())
	assert(parent.get_child_count() > 1, "FAIL: responses must spawn replacement, debris, or fx into parent")

	parent.free()
	print("[PASS] test_destruction_response_integration passed 100%!")
	print("==================================================================")
	quit(0)
