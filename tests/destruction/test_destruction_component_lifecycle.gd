extends SceneTree

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_component_lifecycle ---")
	print("==================================================================")

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical"],
		"destruction_mode": "break"
	})

	var node := Node3D.new()
	var comp := _DestructionCompScript.new(def)
	node.add_child(comp)

	assert(comp.current_state == _DestructionStateScript.State.INTACT, "FAIL: initial state must be INTACT")
	assert(comp.current_durability == 20.0, "FAIL: initial durability")

	# Invulnerable test (e.g. fire hit when only physical is vulnerable)
	var fire_hit = _DestructionHitScript.new(10.0, &"fire")
	var hit_applied = comp.apply_hit(fire_hit)
	assert(not hit_applied, "FAIL: fire hit should not apply when vulnerable to physical only")
	assert(comp.current_durability == 20.0, "FAIL: durability must stay 20")

	# Hit 1: 5 damage -> 15 durability (DAMAGED)
	var hit1 = _DestructionHitScript.new(5.0, &"physical")
	comp.apply_hit(hit1)
	assert(comp.current_durability == 15.0, "FAIL: durability after hit 1")
	assert(comp.current_state == _DestructionStateScript.State.DAMAGED, "FAIL: state after hit 1")

	# Hit 2: 10 damage -> 5 durability (CRITICAL, <= 25%)
	var hit2 = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(hit2)
	assert(comp.current_durability == 5.0, "FAIL: durability after hit 2")
	assert(comp.current_state == _DestructionStateScript.State.CRITICAL, "FAIL: state after hit 2")

	# Hit 3: 10 damage -> 0 durability (DESTROYED)
	var hit3 = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(hit3)
	assert(comp.current_durability == 0.0, "FAIL: durability after hit 3")
	assert(comp.is_destroyed(), "FAIL: must be destroyed")
	assert(comp.current_state == _DestructionStateScript.State.DESTROYED, "FAIL: state after hit 3")

	node.free()
	print("[PASS] test_destruction_component_lifecycle passed with 100% success!")
	print("==================================================================")
	quit(0)
