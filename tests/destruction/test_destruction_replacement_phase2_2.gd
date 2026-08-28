extends SceneTree

const _ReplacementConsumerScript = preload("res://src/destruction/response/replacement/destruction_replacement_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")

func _init() -> void:
	print("==================================================================")
	print("--- AUDITORÍA FASE 2.2: DESTRUCTION REPLACEMENT CONSUMER ---")
	print("==================================================================")

	var provider := _PropAssetProviderScript.new()
	var consumer := _ReplacementConsumerScript.new(provider)

	var parent := Node3D.new()
	var urn_node := Node3D.new()
	parent.add_child(urn_node)
	urn_node.position = Vector3(7.5, 0.0, 14.2)

	# 1. Caso con replacement_asset definido
	var def_with_rep = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_urn_relic_floor"
	})
	var evt_rep = _DestructionEventScript.new(urn_node, def_with_rep, 0, 3, null)
	var ctx_rep = _DestructionContextScript.from_event(evt_rep, 777, 1)

	var rep_node = consumer.handle_replacement(ctx_rep, parent)
	assert(rep_node != null, "FAIL: replacement node must be instantiated when replacement_asset is present")
	assert(rep_node.position.is_equal_approx(Vector3(7.5, 0.0, 14.2)), "FAIL: replacement transform must match original")
	assert(rep_node.has_meta("is_destruction_replacement"), "FAIL: replacement metadata must be set")
	assert(rep_node.get_meta("source_prop_id") == &"crypt_urn_banded_floor", "FAIL: source_prop_id metadata must match")
	print("1. [OK] Materialización de reemplazo con Transform y Metadata correctos.")

	# 2. Caso sin replacement_asset (vacío / none)
	var def_no_rep = _DestructibleDefScript.from_dict(&"candle_cluster", {
		"durability": 5.0,
		"mode": "extinguish"
	})
	var evt_no_rep = _DestructionEventScript.new(urn_node, def_no_rep, 0, 3, null)
	var ctx_no_rep = _DestructionContextScript.from_event(evt_no_rep, 777, 1)

	var no_rep_node = consumer.handle_replacement(ctx_no_rep, parent)
	assert(no_rep_node == null, "FAIL: consumer must return null when no replacement_asset is defined")
	print("2. [OK] Retorno null cuando replacement_asset no está configurado.")

	# 3. Integración con DestructionResponseService
	var response_service := _DestructionResponseServiceScript.new(provider, 1337, parent)
	var resp_dict = response_service.handle_destruction_event(evt_rep)
	assert(resp_dict.has("replacement"), "FAIL: response_service must coordinate replacement")
	assert(resp_dict["replacement"] != null, "FAIL: response_service must return instantiated replacement node")
	print("3. [OK] Integración y delegación desde DestructionResponseService verificadas.")

	parent.free()
	print("\n==================================================================")
	print("[PASS] Auditoría Fase 2.2 (Replacement Consumer) superada al 100%!")
	print("==================================================================")
	quit(0)
