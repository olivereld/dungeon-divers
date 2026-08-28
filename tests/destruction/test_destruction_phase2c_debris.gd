extends SceneTree

const _DebrisConsumerScript = preload("res://src/destruction/response/debris/destruction_debris_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2c_debris (Task 3) ---")
	print("==================================================================")
	var consumer = _DebrisConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(20.0, 0.0, 20.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "debris": "ceramic_small"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 888, 1)

	var shards = consumer.handle_debris(ctx, parent)
	assert(shards.size() >= 3 and shards.size() <= 6, "FAIL: shard count out of bounds")
	for s in shards:
		assert(s.position.distance_to(node.position) <= 2.0, "FAIL: shard too far from origin")
		assert(s.get_parent() == parent, "FAIL: shard parent mismatch")

	parent.free()
	print("[PASS] test_destruction_phase2c_debris passed 100%!")
	print("==================================================================")
	quit(0)
