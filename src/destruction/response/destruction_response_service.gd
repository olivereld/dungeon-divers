class_name DestructionResponseService
extends RefCounted

## Coordinador global de respuestas a eventos de destrucción.
## Recibe DestructionEvents y delega en los consumidores correspondientes
## (Replacement, Debris, Effects) creando un DestructionResponseContext determinista.

const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionReplacementConsumerScript = preload("res://src/destruction/response/replacement/destruction_replacement_consumer.gd")
const _DestructionDebrisConsumerScript = preload("res://src/destruction/response/debris/destruction_debris_consumer.gd")
const _DestructionEffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

var _replacement_consumer: _DestructionReplacementConsumerScript = null
var _debris_consumer: _DestructionDebrisConsumerScript = null
var _effects_consumer: _DestructionEffectsConsumerScript = null
var _base_seed: int = 1337
var _staging_parent: Node3D = null

func _init(
	provider: _PropAssetProviderScript = null,
	base_seed: int = 1337,
	staging_parent: Node3D = null
) -> void:
	_base_seed = base_seed
	_staging_parent = staging_parent
	_replacement_consumer = _DestructionReplacementConsumerScript.new(provider)
	_debris_consumer = _DestructionDebrisConsumerScript.new()
	_effects_consumer = _DestructionEffectsConsumerScript.new()

func set_staging_parent(parent_node: Node3D) -> void:
	_staging_parent = parent_node

func set_base_seed(seed_val: int) -> void:
	_base_seed = seed_val

func set_replacement_consumer(consumer: _DestructionReplacementConsumerScript) -> void:
	_replacement_consumer = consumer

func set_debris_consumer(consumer: _DestructionDebrisConsumerScript) -> void:
	_debris_consumer = consumer

func set_effects_consumer(consumer: _DestructionEffectsConsumerScript) -> void:
	_effects_consumer = consumer

## Maneja la destrucción de un objeto coordinando todos los consumidores registrados.
## Secuencia: 1. Efectos (VFX/SFX) -> 2. Reemplazo de Malla -> 3. Dispersión de Escombros
func handle_destruction_event(evt: _DestructionEventScript) -> Dictionary:
	var result := {
		"effects": [],
		"replacement": null,
		"debris": []
	}

	if evt == null or evt.target == null or not is_instance_valid(evt.target):
		return result

	var parent = _staging_parent
	if parent == null or not is_instance_valid(parent):
		parent = evt.target.get_parent()

	var ctx = _DestructionResponseContextScript.from_event(evt, _base_seed)

	# 1. Ejecutar Efectos de Partículas y VFX (Feedback instantáneo)
	if _effects_consumer != null:
		var fx_nodes = _effects_consumer.handle_effects(ctx, parent)
		result["effects"] = fx_nodes

	# 2. Ejecutar Reemplazo de Representación (si aplica)
	if _replacement_consumer != null:
		var rep_node = _replacement_consumer.handle_replacement(ctx, parent)
		result["replacement"] = rep_node

	# 3. Ejecutar Dispersión de Escombros (si aplica)
	if _debris_consumer != null:
		var debris_nodes = _debris_consumer.handle_debris(ctx, parent)
		result["debris"] = debris_nodes

	return result
