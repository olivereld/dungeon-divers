extends SceneTree

const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_phase2e_orchestration (Task 5) ---")
	print("==================================================================")
	var provider = _PropAssetProviderScript.new()
	var parent = Node3D.new()
	var service = _DestructionResponseServiceScript.new(provider, 1337, parent)

	# 1. Urna: Effects + Replacement + Debris
	var node_urn = Node3D.new()
	parent.add_child(node_urn)
	var def_urn = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "replacement_asset": "crypt_urn_relic_floor",
		"debris": "ceramic_small", "effects": ["dust_small", "ceramic_break"]
	})
	var evt_urn = _DestructionEventScript.new(node_urn, def_urn, 0, 3, null)
	var res_urn = service.handle_destruction_event(evt_urn)

	assert(res_urn["replacement"] != null, "FAIL: urn must have replacement")
	assert(res_urn["debris"].size() >= 3, "FAIL: urn must have debris")
	assert(res_urn["effects"].size() == 2, "FAIL: urn must have 2 fx")
	print("1. [OK] Urna orquestada: Effects (%d) + Replacement (%s) + Debris (%d)" % [
		res_urn["effects"].size(), res_urn["replacement"].name, res_urn["debris"].size()
	])

	# 2. Vela: Extinguish solo effects
	var node_candle = Node3D.new()
	parent.add_child(node_candle)
	var def_candle = _DestructibleDefScript.from_dict(&"candle_cluster", {
		"durability": 5.0, "mode": "extinguish", "effects": ["smoke_puff"]
	})
	var evt_candle = _DestructionEventScript.new(node_candle, def_candle, 0, 3, null)
	var res_candle = service.handle_destruction_event(evt_candle)

	assert(res_candle["replacement"] == null, "FAIL: candle must not have replacement")
	assert(res_candle["debris"].is_empty(), "FAIL: candle must not have debris")
	assert(res_candle["effects"].size() == 1, "FAIL: candle must have 1 smoke fx")
	print("2. [OK] Vela orquestada: Extinguish solo Effects (%d), sin debris ni replacement." % res_candle["effects"].size())

	parent.free()
	print("[PASS] test_destruction_phase2e_orchestration passed 100%!")
	print("==================================================================")
	quit(0)
