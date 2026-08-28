extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_response_core_integration (Task 3) ---")
	print("==================================================================")

	var urn_node := Node3D.new()
	urn_node.position = Vector3(4.0, 0.0, 8.0)
	urn_node.set_meta("room_id", 1)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_rubble_corner",
		"debris": "ceramic_small",
		"effects": ["dust_small", "ceramic_break"]
	})

	var response_service := _DestructionResponseServiceScript.new()
	var d_service := _DestructionServiceScript.new()
	d_service.set_response_service(response_service)

	var comp := _DestructionCompScript.new(def)
	urn_node.add_child(comp)
	d_service.register_instance(urn_node, comp)

	var stats := {"received": false}
	d_service.global_destruction_event.connect(func(e):
		stats["received"] = true
		assert(e.target == urn_node, "FAIL: event target mismatch")
		assert(e.definition == def, "FAIL: event definition mismatch")
	)

	# 1. Aplicar daño parcial (10 HP -> estado DAMAGED)
	var half_hit = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(half_hit)
	assert(not comp.is_destroyed(), "FAIL: should not be destroyed after partial hit")
	assert(not stats["received"], "FAIL: should not emit destruction event on partial damage")

	# 2. Aplicar daño fatal (15 HP -> DESTROYED -> Emisión de evento y respuesta)
	var fatal_hit = _DestructionHitScript.new(15.0, &"physical")
	comp.apply_hit(fatal_hit)
	assert(comp.is_destroyed(), "FAIL: component must be destroyed")
	assert(stats["received"], "FAIL: global_destruction_event must be emitted and forwarded to response service")

	urn_node.free()
	print("[PASS] test_destruction_response_core_integration passed 100%!")
	print("==================================================================")
	quit(0)
