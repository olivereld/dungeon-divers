class_name VFXInstance
extends Node3D

## Controlador de tiempo de ejecución genérico para instancias VFX.
## Descubre y reproduce automáticamente todos los emisores hijos (GPUParticles3D, CPUParticles3D)
## y gestiona su ciclo de vida con auto-cleanup (queue_free()) al finalizar.

signal finished

@export var max_lifetime: float = 1.2
@export var auto_cleanup: bool = true
@export var auto_play: bool = true

var _elapsed_time: float = 0.0
var _is_playing: bool = false
var _has_finished: bool = false

func _ready() -> void:
	if auto_play:
		play()

func _process(delta: float) -> void:
	if not _is_playing or _has_finished:
		return

	_elapsed_time += delta
	if _elapsed_time >= max_lifetime:
		_on_lifetime_expired()

## Inicia la reproducción de todos los emisores de partículas y audio hijos.
func play() -> void:
	_elapsed_time = 0.0
	_is_playing = true
	_has_finished = false
	_trigger_emitters(self, true)

## Detiene la emisión de partículas de los hijos.
func stop() -> void:
	_is_playing = false
	_trigger_emitters(self, false)

## Fuerza la finalización y liberación de memoria inmediata.
func cleanup() -> void:
	_on_lifetime_expired()

func _on_lifetime_expired() -> void:
	if _has_finished:
		return
	_has_finished = true
	_is_playing = false
	finished.emit()

	if auto_cleanup and is_inside_tree():
		queue_free()

func _trigger_emitters(node: Node, emit_state: bool) -> void:
	for child in node.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = emit_state
		elif child is GPUParticles3D:
			(child as GPUParticles3D).emitting = emit_state
		elif child is AudioStreamPlayer3D and emit_state:
			(child as AudioStreamPlayer3D).play()

		if child.get_child_count() > 0:
			_trigger_emitters(child, emit_state)
