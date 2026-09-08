# triggerable.gd
# Marca que la entidad puede responder a una activación (trampas, mecanismos).
# Contrato mínimo a propósito: sin detección de proximidad, colisión, señales,
# daño ni animación — eso llega en fases posteriores fuera de Entities v1.
class_name Triggerable
extends RefCounted

var _can_be_triggered: bool

func _init(p_can_be_triggered: bool = true) -> void:
	_can_be_triggered = p_can_be_triggered

func can_be_triggered() -> bool:
	return _can_be_triggered

func set_can_be_triggered(value: bool) -> void:
	_can_be_triggered = value
