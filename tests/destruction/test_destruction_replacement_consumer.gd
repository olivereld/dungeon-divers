extends SceneTree

const _ReplacementConsumerScript = preload("res://src/destruction/response/destruction_replacement_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_replacement_consumer ---")
	print("==================================================================")

	var provider = _PropAssetProviderScript.new()
	var consumer = _ReplacementConsumerScript.new(provider)

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(2.0, 0.0, 4.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_urn_relic_floor"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 999, 1)

	var rep_node = consumer.handle_replacement(ctx, parent)
	assert(rep_node != null, "FAIL: replacement node must be materialized")
	assert(rep_node.position.is_equal_approx(Vector3(2.0, 0.0, 4.0)), "FAIL: position must match original")

	parent.free()
	print("[PASS] test_destruction_replacement_consumer passed 100%!")
	print("==================================================================")
	quit(0)
