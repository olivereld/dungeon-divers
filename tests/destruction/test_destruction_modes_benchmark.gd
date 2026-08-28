extends SceneTree

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_modes_benchmark ---")
	print("==================================================================")

	var reg := _DestructionRegistryScript.new()
	var service := _DestructionServiceScript.new()
	var binder := _DestructionBinderScript.new(reg, service)
	var provider := _PropAssetProviderScript.new()

	# Benchmark 1: Urn (BREAK mode: durability 20, physical hit -> destroyed)
	var urn = provider.materialize_by_id(&"crypt_urn_banded_floor")
	assert(urn != null, "FAIL: urn node must be instantiated")
	var comp1 = binder.bind_prop(urn, &"crypt_urn_banded_floor")
	assert(comp1 != null, "FAIL: urn must have DestructionComponent attached")
	assert(comp1.current_durability == 20.0, "FAIL: urn starts with 20 durability")

	# Half damage
	service.apply_hit_to_node(urn, _DestructionHitScript.new(10.0, &"physical"))
	assert(comp1.current_durability == 10.0, "FAIL: urn at 10 durability")
	assert(comp1.current_state == _DestructionStateScript.State.DAMAGED, "FAIL: urn state DAMAGED")

	# Fatal damage
	service.apply_hit_to_node(urn, _DestructionHitScript.new(10.0, &"physical"))
	assert(comp1.is_destroyed(), "FAIL: urn must be destroyed")
	assert(not urn.visible, "FAIL: BREAK mode hides root prop mesh")
	print("  [OK] Benchmark 1: Urn (BREAK) verified.")
	urn.free()

	# Benchmark 2: Skull Pile (COLLAPSE mode: durability 15, bludgeoning hit -> collapsed)
	var skulls = provider.materialize_by_id(&"skull_pile")
	assert(skulls != null, "FAIL: skulls node must be instantiated")
	var comp2 = binder.bind_prop(skulls, &"skull_pile")
	assert(comp2 != null, "FAIL: skulls must have DestructionComponent attached")
	assert(comp2.current_durability == 15.0, "FAIL: skull pile starts with 15 durability")

	service.apply_hit_to_node(skulls, _DestructionHitScript.new(15.0, &"crush"))
	assert(comp2.is_destroyed(), "FAIL: skull pile must be destroyed")
	assert(not skulls.visible, "FAIL: COLLAPSE mode hides root prop mesh")
	print("  [OK] Benchmark 2: Skull Pile (COLLAPSE) verified.")
	skulls.free()

	# Benchmark 3: Candle Cluster (EXTINGUISH mode: durability 5, wind hit -> light turned off, node stays visible)
	var candle := Node3D.new()
	var light := OmniLight3D.new()
	candle.add_child(light)
	var comp3 = binder.bind_prop(candle, &"candle_cluster")
	assert(comp3 != null, "FAIL: candle must have DestructionComponent attached")
	assert(light.visible, "FAIL: candle light starts visible")

	service.apply_hit_to_node(candle, _DestructionHitScript.new(5.0, &"wind"))
	assert(comp3.is_destroyed(), "FAIL: candle must be extinguished")
	assert(candle.visible, "FAIL: EXTINGUISH mode keeps candle decoration visible")
	assert(not light.visible, "FAIL: EXTINGUISH mode extinguishes OmniLight3D")
	print("  [OK] Benchmark 3: Candle Cluster (EXTINGUISH) verified.")
	candle.free()

	print("[PASS] test_destruction_modes_benchmark passed with 100% success!")
	print("==================================================================")
	quit(0)
