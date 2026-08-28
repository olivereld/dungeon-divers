extends SceneTree

const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_core_contracts ---")
	print("==================================================================")

	var hit = _DestructionHitScript.new(15.0, &"physical", Vector3(1, 0, 1), Vector3.FORWARD, null)
	assert(hit.damage == 15.0, "FAIL: damage")
	assert(hit.damage_type == &"physical", "FAIL: damage_type")

	var dict = {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical", "bludgeoning"],
		"destruction_mode": "break",
		"replacement_asset": "crypt_rubble_corner",
		"debris": "ceramic_small",
		"effects": ["dust_small"]
	}
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", dict)
	assert(def != null, "FAIL: def is null")
	assert(def.durability == 20.0, "FAIL: durability")
	assert(def.destruction_mode == _DestructionModeScript.Mode.BREAK, "FAIL: mode")
	assert(def.replacement_asset == &"crypt_rubble_corner", "FAIL: replacement")
	assert(def.damage_vulnerabilities.size() == 2, "FAIL: vulnerabilities size")

	var evt = _DestructionEventScript.new(null, def, _DestructionStateScript.State.INTACT, _DestructionStateScript.State.DAMAGED, hit)
	assert(evt.new_state == _DestructionStateScript.State.DAMAGED, "FAIL: event new_state")

	print("[PASS] test_destruction_core_contracts passed with 100% success!")
	print("==================================================================")
	quit(0)
