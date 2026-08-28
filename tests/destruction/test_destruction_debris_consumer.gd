extends SceneTree

const _DebrisConsumerScript = preload("res://src/destruction/response/destruction_debris_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_debris_consumer ---")
	print("==================================================================")

	var consumer = _DebrisConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(10.0, 0.0, 10.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"debris": "ceramic_small"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 42, 1)

	var spawned = consumer.handle_debris(ctx, parent)
	assert(spawned.size() >= 3 and spawned.size() <= 6, "FAIL: debris count must be within catalog bounds (got %d)" % spawned.size())
	for deb in spawned:
		assert(deb.position.distance_to(node.position) <= 2.0, "FAIL: debris must be scattered near origin")
		assert(deb.get_parent() == parent, "FAIL: debris must be child of parent")

	parent.free()
	print("[PASS] test_destruction_debris_consumer passed 100%!")
	print("==================================================================")
	quit(0)
