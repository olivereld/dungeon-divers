extends SceneTree

const _DestructionDebugHUDScript = preload("res://src/destruction/debug/destruction_debug_hud.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_debug_hud ---")
	print("==================================================================")

	var hud := _DestructionDebugHUDScript.new()
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical"],
		"destruction_mode": "break"
	})

	var prop := Node3D.new()
	prop.name = "Prop_Urn_Relic"
	var comp := _DestructionCompScript.new(def)
	prop.add_child(comp)

	hud.update_telemetry(prop, comp, 10.0)
	assert(hud.get_title_text().contains("crypt_urn_banded_floor"), "FAIL: HUD must display asset ID")
	assert(hud.get_durability_text().contains("20.0 / 20.0"), "FAIL: HUD must display durability")

	# Damage comp and update
	comp.apply_hit(_DestructionHitScript.new(10.0, &"physical"))
	hud.update_telemetry(prop, comp, 10.0)
	assert(hud.get_durability_text().contains("10.0 / 20.0"), "FAIL: HUD must update durability")
	assert(hud.get_state_text().contains("DAMAGED"), "FAIL: HUD must show DAMAGED state")

	prop.free()
	hud.free()
	print("[PASS] test_destruction_debug_hud passed with 100% success!")
	print("==================================================================")
	quit(0)
