extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2f_e2e (Task 6) ---")
	print("==================================================================")
	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var staging := Node3D.new()

	var response_service := _DestructionResponseServiceScript.new(provider, 7777, staging)
	d_service.set_response_service(response_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	# 1. Probar Urna (BREAK)
	print("1. Auditando Urna Procedural...")
	var style_urn = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var dir_urn = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style_urn, Vector3(2.0, 0.0, 3.0), 0.0, [Vector2i(1, 1)]
	)
	var urn_node = spawner.spawn_prop(dir_urn, staging)
	assert(urn_node != null, "FAIL: Urn must spawn")
	var urn_comp: _DestructionCompScript = urn_node.get_node("DestructionComponent")
	urn_comp.apply_hit(_DestructionHitScript.new(30.0, &"physical"))

	assert(urn_comp.is_destroyed(), "FAIL: Urn must be destroyed")
	assert(not urn_node.visible, "FAIL: Urn must be hidden")

	var shards := 0
	var fx := 0
	for c in staging.get_children():
		if c.name.begins_with("Debris_"):
			shards += 1
		elif c.name.begins_with("FX_"):
			fx += 1

	print("   [OK] Escombros cerámicos generados en staging: %d" % shards)
	print("   [OK] Partículas VFX generadas en staging: %d" % fx)
	assert(shards >= 3, "FAIL: shards must spawn in staging")
	assert(fx >= 1, "FAIL: fx must spawn in staging")

	# 2. Probar Pila de Calaveras (COLLAPSE)
	print("2. Auditando Pila de Calaveras...")
	var style_sk = _PropStyleScript.new(
		&"skull_pile", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"skull_pile", {}, 0, []
	)
	var dir_sk = _PropDirectiveScript.new(
		&"skull_pile", 1, style_sk, Vector3(8.0, 0.0, 3.0), 0.0, [Vector2i(4, 1)]
	)
	var sk_node = spawner.spawn_prop(dir_sk, staging)
	assert(sk_node != null, "FAIL: Skull pile must spawn")
	var sk_comp: _DestructionCompScript = sk_node.get_node("DestructionComponent")
	sk_comp.apply_hit(_DestructionHitScript.new(20.0, &"physical"))
	assert(sk_comp.is_destroyed(), "FAIL: Skull pile must be destroyed")

	staging.free()
	print("[PASS] test_destruction_phase2f_e2e passed 100%!")
	print("==================================================================")
	quit(0)
