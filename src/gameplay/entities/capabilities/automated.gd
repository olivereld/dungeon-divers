# automated.gd
# Marca que esta entidad puede funcionar autónomamente sin ser una entidad
# viva (torretas, autómatas, trampas activas). NO implica AI ni hostilidad:
# una torreta automatizada puede pertenecer a una facción aliada.
# Contrato mínimo a propósito: sin sensores, timers ni lógica de ataque.
class_name Automated
extends RefCounted

var _is_active: bool

func _init(p_is_active: bool = true) -> void:
	_is_active = p_is_active

var is_active: bool:
	get: return _is_active

func activate() -> void:
	_is_active = true

func deactivate() -> void:
	_is_active = false
