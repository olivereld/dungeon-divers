extends SceneTree

const _DestructionDebugInteractorScript = preload("res://src/destruction/debug/destruction_debug_interactor.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_debug_interactor ---")
	print("==================================================================")

	var interactor := _DestructionDebugInteractorScript.new()
	var service := _DestructionServiceScript.new()
	interactor.set_service(service)

	# 1. Crear jerarquía física simulada (Prop -> StaticBody3D -> CollisionShape3D)
	var prop_root := Node3D.new()
	prop_root.name = "Prop_Urn_Test"
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical"],
		"destruction_mode": "break"
	})
	var comp := _DestructionCompScript.new(def)
	prop_root.add_child(comp)

	var static_body := StaticBody3D.new()
	prop_root.add_child(static_body)

	# 2. Testear resolución desde el collider hijo
	var resolved_comp = interactor.resolve_destructible_from_collider(static_body)
	assert(resolved_comp == comp, "FAIL: interactor must resolve component from child StaticBody3D")

	# 3. Testear ejecución de hit normal (10 damage)
	var hit_res = interactor.apply_hit_to_target(prop_root, 10.0, &"physical", false)
	assert(hit_res.success, "FAIL: hit must succeed")
	assert(comp.current_durability == 10.0, "FAIL: durability after 10 damage")
	assert(comp.current_state == _DestructionStateScript.State.DAMAGED, "FAIL: state must be DAMAGED")

	# 4. Testear ejecución de hit fatal (Right Click simulation)
	var fatal_res = interactor.apply_hit_to_target(prop_root, 10.0, &"physical", true)
	assert(fatal_res.success, "FAIL: fatal hit must succeed")
	assert(comp.is_destroyed(), "FAIL: prop must be destroyed immediately on fatal hit")

	prop_root.free()
	print("[PASS] test_destruction_debug_interactor passed with 100% success!")
	print("==================================================================")
	quit(0)
