extends SceneTree

const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_response_context ---")
	print("==================================================================")

	var node = Node3D.new()
	node.position = Vector3(5, 0, 10)
	var def = _DestructibleDefScript.from_dict(&"test_urn", {"durability": 20.0, "mode": "break"})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)

	var ctx = _DestructionContextScript.from_event(evt, 12345, 1)
	assert(ctx.event == evt, "FAIL: context must retain event")
	assert(ctx.global_transform.origin == Vector3(5, 0, 10), "FAIL: transform origin mismatch")
	assert(ctx.base_seed == 12345, "FAIL: base_seed mismatch")
	assert(ctx.seed_value != 0, "FAIL: seed_value must be computed")
	assert(ctx.room_id == 1, "FAIL: room_id mismatch")
	assert(ctx.rng != null, "FAIL: rng must be initialized")

	# Deterministic random check
	var r1 = ctx.rng.randf()
	var ctx2 = _DestructionContextScript.from_event(evt, 12345, 1)
	var r2 = ctx2.rng.randf()
	assert(is_equal_approx(r1, r2), "FAIL: same seed must yield same deterministic sequence")

	node.free()
	print("[PASS] test_destruction_response_context passed 100%!")
	print("==================================================================")
	quit(0)
