extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/destruction_effects_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_effects_consumer ---")
	print("==================================================================")

	var consumer = _EffectsConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(0, 0, 0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"effects": ["dust_small", "ceramic_break"]
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 100, 1)

	var fx_nodes = consumer.handle_effects(ctx, parent)
	assert(fx_nodes.size() == 2, "FAIL: must trigger 2 effect handlers (got %d)" % fx_nodes.size())
	for fx in fx_nodes:
		assert(fx.get_parent() == parent, "FAIL: fx node must be child of parent")

	parent.free()
	print("[PASS] test_destruction_effects_consumer passed 100%!")
	print("==================================================================")
	quit(0)
