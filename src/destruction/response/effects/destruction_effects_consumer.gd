class_name DestructionEffectsConsumer
extends RefCounted

## Consumidor desacoplado encargado de disparar efectos visuales/partículas (VFX/SFX)
## basándose en las especificaciones declarativas de effects.json.

const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEffectRegistryScript = preload("res://src/destruction/response/effects/destruction_effect_registry.gd")

var _registry: _DestructionEffectRegistryScript = null

func _init(registry: _DestructionEffectRegistryScript = null) -> void:
	_registry = registry if registry != null else _DestructionEffectRegistryScript.new()

## Dispara los efectos configurados en el evento.
func handle_effects(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if ctx == null or ctx.event == null or ctx.event.definition == null:
		return result

	var effect_keys: Array = ctx.event.definition.effects
	if effect_keys.is_empty():
		return result

	var target_parent = staging_parent
	if target_parent == null and ctx.event.target != null and is_instance_valid(ctx.event.target):
		target_parent = ctx.event.target.get_parent()

	var origin_pos := ctx.global_transform.origin

	for eff_key in effect_keys:
		var key_str = str(eff_key)
		if _registry == null or not _registry.has_effect(key_str):
			continue

		var ecfg: Dictionary = _registry.get_effect_config(key_str)
		var emitter := _create_particle_emitter(key_str, ecfg, ctx)
		if emitter != null:
			emitter.position = origin_pos
			if target_parent != null and is_instance_valid(target_parent):
				target_parent.add_child(emitter)
			result.append(emitter)

	return result

func _create_particle_emitter(eff_key: String, cfg: Dictionary, ctx: _DestructionResponseContextScript) -> Node3D:
	var emitter := CPUParticles3D.new()
	emitter.name = "FX_%s" % eff_key
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.9

	var amt = int(cfg.get("amount", 12))
	var life = float(cfg.get("lifetime", 0.8))
	emitter.amount = amt
	emitter.lifetime = life

	var raw_color = cfg.get("color", [1.0, 1.0, 1.0, 1.0])
	emitter.color = Color(raw_color[0], raw_color[1], raw_color[2], raw_color[3])

	emitter.initial_velocity_min = float(cfg.get("initial_velocity_min", 1.0))
	emitter.initial_velocity_max = float(cfg.get("initial_velocity_max", 3.0))
	emitter.spread = float(cfg.get("spread", 180.0))

	var raw_grav = cfg.get("gravity", [0.0, -3.0, 0.0])
	emitter.gravity = Vector3(raw_grav[0], raw_grav[1], raw_grav[2])

	var quad := BoxMesh.new()
	quad.size = Vector3(0.05, 0.05, 0.05)
	emitter.mesh = quad

	return emitter

## Alias de interfaz común para todos los consumidores de respuesta
func handle(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Array[Node3D]:
	return handle_effects(ctx, staging_parent)
