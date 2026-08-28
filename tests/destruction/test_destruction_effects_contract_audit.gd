extends SceneTree

const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionEffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _DestructionEffectRegistryScript = preload("res://src/destruction/response/effects/destruction_effect_registry.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")

func _init() -> void:
	print("==================================================================")
	print("--- AUDITORÍA: DESTRUCTION RESPONSE SERVICE & EFFECTS CONTRACT ---")
	print("==================================================================")

	# 1. Auditoría de DestructionResponseService (Pure Coordinator)
	var service_source = FileAccess.get_file_as_string("res://src/destruction/response/destruction_response_service.gd")
	assert(not "CPUParticles3D" in service_source, "FAIL: DestructionResponseService must not contain particle types")
	assert(not "GPUParticles3D" in service_source, "FAIL: DestructionResponseService must not contain particle types")
	assert(not "BoxMesh" in service_source, "FAIL: DestructionResponseService must not contain mesh generation")
	assert(not "== \"urn\"" in service_source, "FAIL: DestructionResponseService must not have hardcoded urn logic")
	assert(not "== \"chest\"" in service_source, "FAIL: DestructionResponseService must not have hardcoded chest logic")
	assert(not "== \"crate\"" in service_source, "FAIL: DestructionResponseService must not have hardcoded crate logic")
	print("1. [OK] DestructionResponseService es un orquestador 100% puro y desacoplado.")

	# 2. Auditoría del Registry y Catálogo de Efectos
	var reg := _DestructionEffectRegistryScript.new()
	var all_fx = reg.get_all_effect_ids()
	assert(all_fx.size() >= 4, "FAIL: at least 4 semantic effects expected in effects.json")
	assert(reg.has_effect("dust_small"), "FAIL: missing dust_small")
	assert(reg.has_effect("ceramic_break"), "FAIL: missing ceramic_break")
	assert(reg.has_effect("bone_scatter"), "FAIL: missing bone_scatter")
	assert(reg.has_effect("smoke_puff"), "FAIL: missing smoke_puff")
	print("2. [OK] DestructionEffectRegistry validado: catálogo declarativo con %d efectos semánticos." % all_fx.size())

	# 3. Auditoría de Parsing: Strings vs Dictionaries
	var def_strings = _DestructibleDefScript.from_dict(&"urn", {
		"effects": ["dust_small", "ceramic_break"]
	})
	assert(def_strings.effects == ["dust_small", "ceramic_break"], "FAIL: string array parsing mismatch")

	var def_dicts = _DestructibleDefScript.from_dict(&"urn", {
		"effects": [{"id": "dust_small"}, {"id": "ceramic_break"}]
	})
	assert(def_dicts.effects == ["dust_small", "ceramic_break"], "FAIL: dict array parsing mismatch")
	print("3. [OK] DestructibleDefinition parsea uniformemente arrays de strings y arrays de objetos {'id': ...}.")

	# 4. Auditoría de Consumer: Resolución y Ejecución
	var parent := Node3D.new()
	var node := Node3D.new()
	parent.add_child(node)
	node.position = Vector3(10.0, 1.0, 20.0)

	var evt := _DestructionEventScript.new(node, def_dicts, 0, 3, null)
	var ctx := _DestructionContextScript.from_event(evt, 1234, 1)

	var consumer := _DestructionEffectsConsumerScript.new(reg)
	var spawned_fx = consumer.handle_effects(ctx, parent)

	assert(spawned_fx.size() == 2, "FAIL: 2 effect emitters must be created")
	for emitter in spawned_fx:
		assert(emitter is CPUParticles3D, "FAIL: emitter must be CPUParticles3D")
		assert(emitter.position.is_equal_approx(Vector3(10.0, 1.0, 20.0)), "FAIL: emitter position mismatch")
		assert((emitter as CPUParticles3D).emitting == true, "FAIL: emitter must be actively emitting")
		assert((emitter as CPUParticles3D).one_shot == true, "FAIL: emitter must be one_shot")

	print("4. [OK] DestructionEffectsConsumer resuelve effect_id y genera emisores en la posición exacta.")

	parent.free()
	print("\n==================================================================")
	print("[PASS] Auditoría de Contrato de Efectos y Servicio superada al 100%!")
	print("==================================================================")
	quit(0)
