class_name DestructionEffectsConsumer
extends RefCounted

## Consumidor desacoplado encargado de disparar efectos visuales (VFX)
## delegando la resolución e instanciación de PackedScenes a DestructionVFXSpawner.
## No contiene lógica ni creación procedural de partículas en código.

const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionVFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")

var _spawner: _DestructionVFXSpawnerScript = null

func _init(spawner: _DestructionVFXSpawnerScript = null) -> void:
	_spawner = spawner if spawner != null else _DestructionVFXSpawnerScript.new()

func get_spawner() -> _DestructionVFXSpawnerScript:
	return _spawner

## Dispara los efectos configurados en el evento delegando a DestructionVFXSpawner.
func handle_effects(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if ctx == null or ctx.event == null or ctx.event.definition == null or _spawner == null:
		return result

	var effect_keys: Array = ctx.event.definition.effects
	if effect_keys.is_empty():
		return result

	var target_parent = staging_parent
	if target_parent == null and ctx.event.target != null and is_instance_valid(ctx.event.target):
		target_parent = ctx.event.target.get_parent()

	var origin_xform: Transform3D = ctx.global_transform

	for eff_key in effect_keys:
		var eff_id := str(eff_key)
		if eff_id == "" or eff_id == "none":
			continue

		var vfx_node = _spawner.spawn_effect(eff_id, origin_xform, target_parent)
		if vfx_node != null:
			result.append(vfx_node)

	return result

## Alias de interfaz común para todos los consumidores de respuesta
func handle(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	return handle_effects(ctx, staging_parent)
