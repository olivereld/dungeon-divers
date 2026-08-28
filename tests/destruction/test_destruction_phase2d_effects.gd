extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _EffectRegistryScript = preload("res://src/destruction/response/effects/destruction_effect_registry.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2d_effects (Task 4) ---")
	print("==================================================================")
	var reg = _EffectRegistryScript.new()
	assert(reg.has_effect("dust_small"), "FAIL: registry must contain dust_small")
	assert(reg.has_effect("ceramic_break"), "FAIL: registry must contain ceramic_break")

	var consumer = _EffectsConsumerScript.new(reg)
	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(0, 0, 0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "effects": ["dust_small", "ceramic_break"]
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 555, 1)

	var fx = consumer.handle_effects(ctx, parent)
	assert(fx.size() == 2, "FAIL: 2 particle emitters must be generated")

	parent.free()
	print("[PASS] test_destruction_phase2d_effects passed 100%!")
	print("==================================================================")
	quit(0)
