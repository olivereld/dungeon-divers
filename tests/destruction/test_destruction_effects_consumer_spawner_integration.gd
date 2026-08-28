extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_effects_consumer_spawner_integration (Task 4) ---")
	print("==================================================================")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var consumer = _EffectsConsumerScript.new(spawner)

	var parent = Node3D.new()
	var target = Node3D.new()
	parent.add_child(target)
	target.position = Vector3(5, 0, 10)

	var def = _DestructibleDefScript.from_dict(&"test_prop", {
		"durability": 20.0, "mode": "break", "effects": [{"id": "small_dust"}]
	})
	var evt = _DestructionEventScript.new(target, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 1337, 1)

	var nodes = consumer.handle_effects(ctx, parent)
	assert(nodes.size() == 1, "FAIL: 1 VFX instance must be returned")
	assert(nodes[0].position.is_equal_approx(Vector3(5, 0, 10)), "FAIL: VFX position mismatch")

	parent.free()
	print("[PASS] test_destruction_effects_consumer_spawner_integration passed 100%!")
	print("==================================================================")
	quit(0)
