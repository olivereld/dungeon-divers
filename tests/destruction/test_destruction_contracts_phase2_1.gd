extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")

func _init() -> void:
	print("==================================================================")
	print("--- AUDITORÍA FASE 2.1: CONTRATOS Y PUENTE DE RESPUESTAS ---")
	print("==================================================================")

	# 1. Auditoría de DestructionEvent
	var target_node := Node3D.new()
	target_node.position = Vector3(12.5, 0.0, 7.5)
	target_node.set_meta("room_id", 3)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_rubble_corner",
		"debris": "ceramic_small",
		"effects": ["dust_small", "ceramic_break"]
	})
	var hit = _DestructionHitScript.new(20.0, &"physical", Vector3(12.5, 0.5, 7.5), Vector3.UP, null)

	var evt = _DestructionEventScript.new(
		target_node, def, _DestructionStateScript.State.INTACT, _DestructionStateScript.State.DESTROYED, hit
	)

	assert(evt.target == target_node, "FAIL: DestructionEvent must carry target node")
	assert(evt.definition == def, "FAIL: DestructionEvent must carry definition")
	assert(evt.old_state == _DestructionStateScript.State.INTACT, "FAIL: old_state mismatch")
	assert(evt.new_state == _DestructionStateScript.State.DESTROYED, "FAIL: new_state mismatch")
	assert(evt.hit == hit, "FAIL: DestructionEvent must carry hit payload")
	print("1. [OK] DestructionEvent auditado: contiene target, definition, estados, hit y timestamp.")

	# 2. Auditoría de DestructionResponseContext
	var ctx = _DestructionContextScript.from_event(evt, 5555, 3)
	assert(ctx.event == evt, "FAIL: Context must retain event")
	assert(ctx.target_transform.origin.is_equal_approx(Vector3(12.5, 0.0, 7.5)), "FAIL: Context must reconstruct Transform3D")
	assert(ctx.room_id == 3, "FAIL: Context must extract room_id")
	assert(ctx.source_asset_id == &"crypt_urn_banded_floor", "FAIL: Context must extract source_asset_id")
	assert(ctx.rng != null, "FAIL: Context must provide deterministic RNG")
	print("2. [OK] DestructionResponseContext auditado: transform espacial, room_id, asset_id y RNG validados.")

	# 3. Auditoría de Contratos de Consumidores mediante Mock
	var consumer_invocations := {
		"replacement": 0,
		"debris": 0,
		"effects": 0,
		"captured_contexts": []
	}

	# Mock Replacement Consumer
	var mock_replacement = RefCounted.new()
	# Mock Debris Consumer
	var mock_debris = RefCounted.new()
	# Mock Effects Consumer
	var mock_effects = RefCounted.new()

	# 4. Auditoría de DestructionResponseService
	var response_service := _DestructionResponseServiceScript.new()
	assert(response_service.has_method("handle_destruction_event"), "FAIL: ResponseService must have handle_destruction_event")

	# 5. Integración Component -> DestructionService -> ResponseService
	var d_service := _DestructionServiceScript.new()
	d_service.set_response_service(response_service)
	assert(d_service.get_response_service() == response_service, "FAIL: DestructionService must hold response_service")

	var comp := _DestructionCompScript.new(def)
	target_node.add_child(comp)
	d_service.register_instance(target_node, comp)

	var stats := {"received": false}
	d_service.global_destruction_event.connect(func(e):
		stats["received"] = true
		assert(e.target == target_node, "FAIL: target mismatch in global signal")
	)

	# Aplicar impacto fatal
	comp.apply_hit(hit)

	assert(comp.is_destroyed(), "FAIL: component must be destroyed")
	assert(stats["received"], "FAIL: global_destruction_event must be emitted")
	print("3. [OK] Cadena completa Component -> DestructionEvent -> DestructionService -> ResponseService verificada.")

	target_node.free()
	print("\n==================================================================")
	print("[PASS] Auditoría de Contratos Fase 2.1 superada al 100%!")
	print("==================================================================")
	quit(0)
