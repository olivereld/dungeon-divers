class_name DestructionEvent
extends RefCounted

## Evento emitido ante impactos, transiciones de estado o destrucción final de un objeto.

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

var target: Node3D = null
var definition: _DestructibleDefScript = null
var old_state: int = 0
var new_state: int = 0
var hit: _DestructionHitScript = null
var timestamp_ms: int = 0

func _init(
	p_target: Node3D = null,
	p_def = null,
	p_old_state: int = 0,
	p_new_state: int = 0,
	p_hit = null
) -> void:
	target = p_target
	definition = p_def
	old_state = p_old_state
	new_state = p_new_state
	hit = p_hit
	timestamp_ms = Time.get_ticks_msec()
