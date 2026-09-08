# integrity.gd
# Equivalente de Health para entidades NO vivas (barriles, torretas, trampas).
# Vocabulario deliberadamente distinto: un barril no "tiene vida", tiene
# integridad estructural.
#
# Invariantes:
#   max_integrity > 0
#   0 <= integrity <= max_integrity
class_name Integrity
extends RefCounted

var _max_integrity: float
var _integrity: float

func _init(p_max_integrity: float) -> void:
	assert(p_max_integrity > 0.0, "Integrity: max_integrity debe ser mayor que 0")
	_max_integrity = p_max_integrity
	_integrity = p_max_integrity

var max_integrity: float:
	get: return _max_integrity

var integrity: float:
	get: return _integrity

func apply_damage(amount: float) -> float:
	var clamped_amount: float = max(0.0, amount)
	var before: float = _integrity
	_integrity = clamp(_integrity - clamped_amount, 0.0, _max_integrity)
	return before - _integrity

func repair(amount: float) -> float:
	var clamped_amount: float = max(0.0, amount)
	var before: float = _integrity
	_integrity = clamp(_integrity + clamped_amount, 0.0, _max_integrity)
	return _integrity - before

func is_destroyed() -> bool:
	return _integrity <= 0.0

func get_integrity_ratio() -> float:
	return _integrity / _max_integrity
