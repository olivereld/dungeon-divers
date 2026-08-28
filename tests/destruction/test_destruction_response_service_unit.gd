extends SceneTree

const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_response_service_unit (Task 2) ---")
	print("==================================================================")

	var node = Node3D.new()
	node.position = Vector3(10, 0, 20)
	var def = _DestructibleDefScript.from_dict(&"test_prop", {"durability": 20.0, "mode": "break"})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)

	var service = _DestructionResponseServiceScript.new()
	assert(service.has_method("handle_destruction_event"), "FAIL: service must have handle_destruction_event method")

	var response_dict = service.handle_destruction_event(evt)
	assert(response_dict is Dictionary, "FAIL: handle_destruction_event must return Dictionary")
	assert(response_dict.has("replacement") and response_dict.has("debris") and response_dict.has("effects"), "FAIL: dictionary must have standard consumer keys")

	node.free()
	print("[PASS] test_destruction_response_service_unit passed 100%!")
	print("==================================================================")
	quit(0)
