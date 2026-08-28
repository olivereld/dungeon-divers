extends SceneTree

const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2a_response_core (Task 1) ---")
	print("==================================================================")
	var node = Node3D.new()
	node.position = Vector3(8.0, 0.0, 16.0)
	node.set_meta("room_id", 4)

	var def = _DestructibleDefScript.from_dict(&"test_urn", {
		"durability": 20.0, "mode": "break", "replacement_asset": "broken_urn"
	})
	var hit = _DestructionHitScript.new(20.0, &"physical", Vector3(8, 0, 16), Vector3.UP, null)
	var evt = _DestructionEventScript.new(node, def, 0, 3, hit)

	var ctx = _DestructionContextScript.from_event(evt, 9999, 4)
	assert(ctx.event == evt, "FAIL: ctx must carry event")
	assert(ctx.target_transform.origin.is_equal_approx(Vector3(8, 0, 16)), "FAIL: ctx origin mismatch")
	assert(ctx.room_id == 4, "FAIL: ctx room_id mismatch")
	assert(ctx.source_asset_id == &"test_urn", "FAIL: ctx source_asset_id mismatch")
	assert(ctx.rng != null, "FAIL: ctx rng required")

	var response_service = _DestructionResponseServiceScript.new()
	var d_service = _DestructionServiceScript.new()
	d_service.set_response_service(response_service)

	var comp = _DestructionCompScript.new(def)
	node.add_child(comp)
	d_service.register_instance(node, comp)

	var captured := {"notified": false}
	d_service.global_destruction_event.connect(func(e): captured["notified"] = true)

	comp.apply_hit(hit)
	assert(comp.is_destroyed(), "FAIL: comp must be destroyed")
	assert(captured["notified"], "FAIL: event must reach d_service and response_service")

	node.free()
	print("[PASS] test_destruction_phase2a_response_core passed 100%!")
	print("==================================================================")
	quit(0)
