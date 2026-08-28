class_name DestructionComponent
extends Node

## Componente de integridad física y ciclo de vida de destrucción.
## Se adhiere al nodo raíz del prop/fixture sin acoplar lógica de renderizado ni generación.

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

signal damaged(hit: _DestructionHitScript, remaining_durability: float)
signal state_changed(old_state: int, new_state: int)
signal destroyed(event: _DestructionEventScript)

var definition: _DestructibleDefScript = null
var current_durability: float = 100.0
var max_durability: float = 100.0
var current_state: int = _DestructionStateScript.State.INTACT

func _init(p_def: _DestructibleDefScript = null) -> void:
	if p_def != null:
		setup(p_def)

func setup(p_def: _DestructibleDefScript) -> void:
	definition = p_def
	max_durability = p_def.durability
	current_durability = max_durability
	current_state = _DestructionStateScript.State.INTACT

func apply_hit(hit: _DestructionHitScript) -> bool:
	if is_destroyed() or definition == null or not definition.enabled:
		return false
	if hit == null or hit.damage <= 0.0:
		return false

	# Filtrado por vulnerabilidades si están especificadas
	if not definition.damage_vulnerabilities.is_empty():
		var type_str = str(hit.damage_type).to_lower()
		var is_vulnerable := false
		for v in definition.damage_vulnerabilities:
			if str(v).to_lower() == type_str:
				is_vulnerable = true
				break
		if not is_vulnerable:
			return false

	var old_dur = current_durability
	current_durability = maxf(0.0, current_durability - hit.damage)
	damaged.emit(hit, current_durability)

	var old_st = current_state
	var new_st = _calculate_state(current_durability, max_durability)
	if new_st != old_st:
		current_state = new_st
		state_changed.emit(old_st, new_st)

	if current_state == _DestructionStateScript.State.DESTROYED:
		var parent_3d = get_parent() as Node3D
		var evt = _DestructionEventScript.new(parent_3d, definition, old_st, current_state, hit)
		destroyed.emit(evt)
		_execute_destruction_mode(evt)

	return true

func is_destroyed() -> bool:
	return current_state == _DestructionStateScript.State.DESTROYED

func _calculate_state(dur: float, max_dur: float) -> int:
	if dur <= 0.0:
		return _DestructionStateScript.State.DESTROYED
	var ratio = dur / max_dur if max_dur > 0.0 else 0.0
	if ratio <= 0.25:
		return _DestructionStateScript.State.CRITICAL
	elif ratio < 1.0:
		return _DestructionStateScript.State.DAMAGED
	return _DestructionStateScript.State.INTACT

func _execute_destruction_mode(evt: _DestructionEventScript) -> void:
	if definition == null or evt.target == null:
		return

	match definition.destruction_mode:
		_DestructionModeScript.Mode.BREAK, _DestructionModeScript.Mode.COLLAPSE:
			evt.target.visible = false
			_disable_colliders_recursive(evt.target)

		_DestructionModeScript.Mode.EXTINGUISH:
			_extinguish_lights_recursive(evt.target)

		_DestructionModeScript.Mode.DISABLE:
			evt.target.process_mode = Node.PROCESS_MODE_DISABLED

static func _disable_colliders_recursive(n: Node) -> void:
	if n is CollisionShape3D:
		(n as CollisionShape3D).disabled = true
	elif n is CollisionObject3D:
		(n as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
	for c in n.get_children():
		_disable_colliders_recursive(c)

static func _extinguish_lights_recursive(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		(n as Light3D).visible = false
	if n is GPUParticles3D or n is CPUParticles3D:
		n.emitting = false
	for c in n.get_children():
		_extinguish_lights_recursive(c)
