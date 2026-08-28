extends SceneTree

const _ReplacementConsumerScript = preload("res://src/destruction/response/replacement/destruction_replacement_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2b_replacement (Task 2) ---")
	print("==================================================================")
	var provider = _PropAssetProviderScript.new()
	var consumer = _ReplacementConsumerScript.new(provider)

	var parent = Node3D.new()
	var original_node = Node3D.new()
	parent.add_child(original_node)
	original_node.position = Vector3(14.0, 0.0, 22.0)

	# 1. Caso con replacement
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "replacement_asset": "crypt_urn_relic_floor"
	})
	var evt = _DestructionEventScript.new(original_node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 1234, 1)

	var rep = consumer.handle_replacement(ctx, parent)
	assert(rep != null, "FAIL: replacement node must be instantiated")
	assert(rep.position.is_equal_approx(Vector3(14.0, 0.0, 22.0)), "FAIL: position must match original")
	assert(rep.get_meta("is_destruction_replacement") == true, "FAIL: replacement meta flag required")
	assert(rep.get_meta("source_prop_id") == &"crypt_urn_banded_floor", "FAIL: source prop id meta required")

	# 2. Caso sin replacement
	var def_empty = _DestructibleDefScript.from_dict(&"skull_pile", {"durability": 15.0, "mode": "collapse"})
	var evt_empty = _DestructionEventScript.new(original_node, def_empty, 0, 3, null)
	var ctx_empty = _DestructionContextScript.from_event(evt_empty, 1234, 1)
	assert(consumer.handle_replacement(ctx_empty, parent) == null, "FAIL: must return null when no replacement defined")

	parent.free()
	print("[PASS] test_destruction_phase2b_replacement passed 100%!")
	print("==================================================================")
	quit(0)
