class_name DestructionEffectsConsumer
extends RefCounted

## Consumidor desacoplado encargado de disparar efectos visuales/partículas (VFX/SFX)
## basándose en las especificaciones declarativas de effects.json.

const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")

var _effects_catalog: Dictionary = {}
var _catalog_path: String = "res://resources/dungeon_profiles/assets/effects.json"

func _init(catalog_path: String = "") -> void:
	if catalog_path != "":
		_catalog_path = catalog_path
	_load_catalog()

func _load_catalog() -> void:
	if not ResourceLoader.exists(_catalog_path) and not FileAccess.file_exists(_catalog_path):
		return
	var file := FileAccess.open(_catalog_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.has("effects"):
			_effects_catalog = parsed["effects"]

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
		if not _effects_catalog.has(key_str):
			continue

		var ecfg: Dictionary = _effects_catalog[key_str]
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

	# Mesh para partículas
	var quad := BoxMesh.new()
	quad.size = Vector3(0.05, 0.05, 0.05)
	emitter.mesh = quad

	return emitter
